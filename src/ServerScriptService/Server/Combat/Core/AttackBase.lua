--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.ActionExecutor)
local StunManager = require(script.Parent.Parent.Utility.StunManager)
local AnimationTimingCache = require(script.Parent.Parent.Utility.AnimationTimingCache)
local AttackFlags = require(script.Parent.Parent.Utility.AttackFlags)
local Block = require(script.Parent.Parent.Actions.Block)
local KnockbackManager = require(script.Parent.Parent.Utility.KnockbackManager)
local LatencyCompensation = require(script.Parent.Parent.Utility.LatencyCompensation)
local HitValidation = require(script.Parent.Parent.Utility.HitValidation)
local EntityAnimator = require(script.Parent.Parent.Utility.EntityAnimator)

local StateTypes = require(Shared.Config.Enums.StateTypes)
local CombatBalance = require(Shared.Config.Balance.CombatBalance)
local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)
local Hitbox = require(Shared.Packages.Hitbox)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local AttackBase = {}

AttackBase.Debug = false

local DefenderGraceWindow = 0.05

local function GetFallbackHitPosition(AttackerRootPart: BasePart, TargetCharacter: Model): Vector3?
	local TargetPivot = TargetCharacter:GetPivot()
	local TargetSize = TargetCharacter:GetExtentsSize()
	if TargetSize.Magnitude <= 0 then
		return nil
	end

	local HalfSize = TargetSize * 0.5
	local AttackerPosition = AttackerRootPart.Position

	local LocalPoint = TargetPivot:PointToObjectSpace(AttackerPosition)

	local ClampedLocalPoint = Vector3.new(
		math.clamp(LocalPoint.X, -HalfSize.X, HalfSize.X),
		math.clamp(LocalPoint.Y, -HalfSize.Y, HalfSize.Y),
		math.clamp(LocalPoint.Z, -HalfSize.Z, HalfSize.Z)
	)

	return TargetPivot:PointToWorldSpace(ClampedLocalPoint)
end

local function CheckLineOfSight(AttackerRootPart: BasePart, TargetCharacter: Model): boolean
	if not AttackerRootPart or not AttackerRootPart.Parent then return false end

	local TargetRootPart = TargetCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		or TargetCharacter:FindFirstChild("Torso") :: BasePart?
		or TargetCharacter:FindFirstChild("UpperTorso") :: BasePart?

	if not TargetRootPart then
		return false
	end

	local Origin = AttackerRootPart.Position
	local Direction = (TargetRootPart.Position - Origin).Unit
	local Distance = (TargetRootPart.Position - Origin).Magnitude

	local RaycastParams = RaycastParams.new()
	RaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParams.FilterDescendantsInstances = { workspace.Characters, workspace.Debris }
	RaycastParams.IgnoreWater = true

	local RaycastResult = workspace:Raycast(Origin, Direction * Distance, RaycastParams)

	return RaycastResult == nil
end

local function HandleClash(ContextA: ActionContext, ContextB: ActionContext, HitPosition: Vector3?)
	ContextA.Entity.States:SetState("Clashing", true)
	ContextB.Entity.States:SetState("Clashing", true)

	ContextA.CustomData.ClashNegated = true
	ContextB.CustomData.ClashNegated = true

	Ensemble.Events.Publish(CombatEvents.ClashOccurred, {
		EntityA = ContextA.Entity,
		EntityB = ContextB.Entity,
		HitPosition = HitPosition,
	})

	task.delay(0.3, function()
		if ContextA.Entity.States then
			ContextA.Entity.States:SetState("Clashing", false)
		end
		if ContextB.Entity.States then
			ContextB.Entity.States:SetState("Clashing", false)
		end
	end)
end

function AttackBase.SetupHitbox(Context: ActionContext, OnHitCallback: (Entity, Vector3?) -> ())
	local RootPart = Context.Entity.Character and Context.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return
	end

	local Metadata = Context.Metadata
	local HitboxSize = Metadata.HitboxSize or Vector3.new(4, 4, 4)
	local HitboxOffset = CFrame.new(Metadata.HitboxOffset or Vector3.new(0, 0, -3))

	local NewHitbox = Hitbox.new({
		SizeOrPart = HitboxSize,
		InitialCframe = RootPart.CFrame * HitboxOffset,
		VelocityPrediction = true,
		Debug = AttackBase.Debug,
		LifeTime = 0,
		LookingFor = "Humanoid",
		Blacklist = { Context.Entity.Character },
		DebounceTime = 0,
		SpatialOption = "InBox",
	})

	if NewHitbox.Part then
		NewHitbox.Part.CastShadow = false
	end

	NewHitbox:WeldTo(RootPart, HitboxOffset)

	NewHitbox.OnHit:Connect(function(HitCharacters: { Model }, HitParts: { BasePart }?)
		if not Context.CustomData.HitWindowOpen or Context.CustomData.HasHit then
			return
		end

		if not ActionValidator.CanPerform(Context.Entity:GetComponent("States"), "Hitbox") then
			return
		end

		for Index, TargetCharacter in HitCharacters do
			local TargetEntity = Ensemble.GetEntity(TargetCharacter)
			if not TargetEntity or TargetEntity == Context.Entity then
				continue
			end

			local HitPosition: Vector3? = nil

			if HitParts and HitParts[Index] then
				HitPosition = HitParts[Index].Position
			else
				HitPosition = GetFallbackHitPosition(RootPart, TargetCharacter)
			end

			local ValidationResult = HitValidation.ValidateHit(Context :: any, TargetEntity, HitPosition)
			if not ValidationResult.IsValid then
				continue
			end

			if not CheckLineOfSight(RootPart, TargetCharacter) then
				continue
			end

			local FinalHitPosition = ValidationResult.RewindedPosition or HitPosition

			Context.CustomData.HasHit = true
			Context.CustomData.LastHitTarget = TargetEntity
			Context.CustomData.LastHitPosition = FinalHitPosition
			OnHitCallback(TargetEntity, FinalHitPosition)
			break
		end
	end)

	Context.CustomData.ActiveHitbox = NewHitbox
end

function AttackBase.ExecuteTimedAttack(Context: ActionContext, Config: {
	OnHitStart: (() -> ())?,
	OnHitEnd: (() -> ())?,
	OnAnimationEnd: (() -> ())?,
})
	local Player = Context.Entity.Player
	local Character = Context.Entity.Character

	local Metadata = Context.Metadata
	local AnimationId = Metadata.AnimationId
	if not AnimationId then
		return
	end

	local AnimationLength = AnimationTimingCache.GetLength(AnimationId) or Metadata.FallbackLength or 1.0
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationId, "HitStart", Metadata.FallbackHitStart or 0.2)
	local HitEndTime = AnimationTimingCache.GetTiming(AnimationId, "HitStop", Metadata.FallbackHitEnd or 0.5)

	if not HitStartTime or not HitEndTime then
		return
	end

	local InputTimestamp = Context.InputData and Context.InputData.InputTimestamp
	local InputCompensation = LatencyCompensation.GetCompensation(InputTimestamp)
	Context.CustomData.InputCompensation = InputCompensation

	if Player then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	elseif Character then
		EntityAnimator.Play(Character, AnimationId)
	end

	local StartTimestamp = os.clock() - InputCompensation

	local function WaitUntil(TargetTime: number): boolean
		local Remaining = TargetTime - (os.clock() - StartTimestamp)
		if Remaining > 0 then
			task.wait(Remaining)
		end
		return not Context.Interrupted
	end

	if not WaitUntil(HitStartTime) then
		return
	end

	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = true
	Context.CustomData.HitWindowOpenTime = os.clock()

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Start()
	end

	Ensemble.Events.Publish(CombatEvents.HitWindowOpened, {
		Entity = Context.Entity,
		ActionName = Metadata.ActionName,
		Context = Context,
	})

	if Config.OnHitStart then
		Config.OnHitStart()
	end

	if not WaitUntil(HitEndTime) then
		return
	end

	Context.CustomData.HitWindowOpen = false

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Stop()
	end

	Ensemble.Events.Publish(CombatEvents.HitWindowClosed, {
		Entity = Context.Entity,
		ActionName = Metadata.ActionName,
		Context = Context,
		DidHit = Context.CustomData.HasHit,
	})

	if Config.OnHitEnd then
		Config.OnHitEnd()
	end

	if not WaitUntil(AnimationLength) then
		return
	end

	if Config.OnAnimationEnd then
		Config.OnAnimationEnd()
	end
end

function AttackBase.ProcessHit(AttackerContext: ActionContext, Target: Entity, HitPosition: Vector3?): boolean
	local TargetContext = ActionExecutor.GetActiveContext(Target)
	local Metadata = AttackerContext.Metadata
	local Damage = Metadata.Damage or 10
	local Flags = AttackFlags.GetFlags(Metadata)

	if AttackerContext.Interrupted or AttackerContext.Entity.States:GetState("Stunned") then
		return false
	end

	if AttackerContext.CustomData.ClashNegated then
		return true
	end

	local TargetIsDodging = Target.States:GetState("Dodging")
	local TargetIsInvulnerable = Target.States:GetState("Invulnerable")

	if TargetIsInvulnerable then
		Ensemble.Events.Publish(CombatEvents.DamageDodged, {
			Entity = Target,
			Attacker = AttackerContext.Entity,
			Damage = Damage,
			HitPosition = HitPosition,
		})
		return true
	end

	if HitValidation.ShouldFavorDefender(Target, DefenderGraceWindow) then
		Ensemble.Events.Publish(CombatEvents.DamageDodged, {
			Entity = Target,
			Attacker = AttackerContext.Entity,
			Damage = Damage,
			HitPosition = HitPosition,
		})
		return true
	end

	if TargetIsDodging then
		ActionExecutor.Interrupt(Target, "Hit")

		Ensemble.Events.Publish(CombatEvents.DodgeCancelExecuted, {
			Entity = Target,
			SourceAction = "Hit",
			Attacker = AttackerContext.Entity,
		})
	end

	if TargetContext and TargetContext.Metadata.ActionType == "Attack" then
		if TargetContext.CustomData.HitWindowOpen then
			local TargetHitTime = TargetContext.CustomData.HitWindowOpenTime or 0
			local AttackerHitTime = AttackerContext.CustomData.HitWindowOpenTime or 0
			local TimeDifference = math.abs(TargetHitTime - AttackerHitTime)

			if TimeDifference <= CombatBalance.Attacking.ClashWindowSeconds then
				HandleClash(AttackerContext, TargetContext, HitPosition)
				return true
			end
		end
	end

	if TargetContext and TargetContext.Metadata.ActionName == "Block" then
		local WasBlocked = Block.OnHit(TargetContext, AttackerContext.Entity, Damage, Flags, HitPosition)

		if WasBlocked then
			Ensemble.Events.Publish(CombatEvents.AttackBlocked, {
				Attacker = AttackerContext.Entity,
				Target = Target,
				Damage = Damage,
				Flags = Flags,
				HitPosition = HitPosition,
				AttackerContext = AttackerContext,
				TargetContext = TargetContext,
			})

			if AttackFlags.HasFlag(Flags, AttackFlags.KNOCKBACK_THROUGH_BLOCK) then
				AttackBase.ApplyKnockback(AttackerContext, Target)
			end

			return true
		end
	end

	AttackBase.ApplyDamage(AttackerContext, Target, HitPosition)
	AttackBase.ApplyHitStun(AttackerContext, Target)
	AttackBase.ApplyKnockback(AttackerContext, Target)

	Ensemble.Events.Publish(CombatEvents.AttackHit, {
		Entity = AttackerContext.Entity,
		Target = Target,
		Damage = Damage,
		Flags = Flags,
		HitPosition = HitPosition,
		Context = AttackerContext,
	})

	return false
end

function AttackBase.ApplyDamage(Context: ActionContext, Target: Entity, HitPosition: Vector3?)
	local Damage = Context.Metadata.Damage or 10

	local DamageComponent = Target:GetComponent("Damage")
	if DamageComponent then
		DamageComponent:DealDamage(Damage, Context.Entity.Player or Context.Entity.Character)
	end

	local SelfState = Context.Entity:GetComponent("States")
	local TargetState = Target:GetComponent("States")

	if SelfState then
		SelfState:SetStateWithDuration(StateTypes.IN_COMBAT, CombatBalance.InCombat.Duration)
	end
	if TargetState then
		TargetState:SetStateWithDuration(StateTypes.IN_COMBAT, CombatBalance.InCombat.Duration)
	end

	Ensemble.Events.Publish(CombatEvents.DamageDealt, {
		Entity = Context.Entity,
		Target = Target,
		Damage = Damage,
		HitPosition = HitPosition,
		ActionName = Context.Metadata.ActionName,
		Context = Context,
	})

	Ensemble.Events.Publish("DamageIndicatorTriggered", {
		Attacker = Context.Entity,
		Target = Target,
		DamageAmount = Damage,
		HitPosition = HitPosition or Target.Character:GetPivot().Position,
		IndicatorType = "Normal",
	})
end

function AttackBase.ApplyKnockback(Context: ActionContext, Target: Entity)
	local Knockback = Context.Metadata.Knockback
	if not Knockback or Knockback <= 0 then
		return
	end

	KnockbackManager.Apply(Target, Context.Entity, Knockback)
end

function AttackBase.ApplyHitStun(Context: ActionContext, Target: Entity)
	local HitStun = Context.Metadata.HitStun or 0

	if HitStun > 0 then
		StunManager.ApplyStun(Target, HitStun, Context.Metadata.ActionName)
	end
end

function AttackBase.ConsumeStamina(Context: ActionContext)
	local StaminaCost = Context.Metadata.StaminaCost or 0
	if StaminaCost <= 0 then
		return
	end

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent then
		StaminaComponent:ConsumeStamina(StaminaCost)
		Context.CustomData.StaminaConsumed = StaminaCost

		Ensemble.Events.Publish(CombatEvents.StaminaConsumed, {
			Entity = Context.Entity,
			Amount = StaminaCost,
			ActionName = Context.Metadata.ActionName,
		})
	end
end

function AttackBase.HandleStaminaRefund(Context: ActionContext)
	if not Context.CustomData.HasHit then
		return
	end

	local StaminaConsumed = Context.CustomData.StaminaConsumed or 0
	local RefundPercent = Context.Metadata.StaminaCostHitReduction or 0

	if StaminaConsumed <= 0 or RefundPercent <= 0 then
		return
	end

	local RefundAmount = StaminaConsumed * RefundPercent

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent then
		StaminaComponent:RestoreStamina(RefundAmount)

		Ensemble.Events.Publish(CombatEvents.StaminaRefunded, {
			Entity = Context.Entity,
			Amount = RefundAmount,
			ActionName = Context.Metadata.ActionName,
		})
	end
end

function AttackBase.CleanupAttack(Context: ActionContext)
	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Stop()
		Context.CustomData.ActiveHitbox:Destroy()
		Context.CustomData.ActiveHitbox = nil
	end
end

return AttackBase