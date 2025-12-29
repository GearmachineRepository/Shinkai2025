--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.CombatTypes)
local CombatEvents = require(script.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.ActionExecutor)
local Block = require(script.Parent.Actions.Block)
local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local Packets = require(Shared.Networking.Packets)
local Hitbox = require(Shared.Packages.Hitbox)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local AttackBase = {}

function AttackBase.SetupHitbox(Context: ActionContext, OnHitCallback: (Entity) -> ())
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
		Debug = true,
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

	NewHitbox.OnHit:Connect(function(HitCharacters: { Model })
		if not Context.CustomData.HitWindowOpen or Context.CustomData.HasHit then
			return
		end

		for _, TargetCharacter in HitCharacters do
			local TargetEntity = Ensemble.GetEntity(TargetCharacter)
			if not TargetEntity or TargetEntity == Context.Entity then
				continue
			end

			Context.CustomData.HasHit = true
			Context.CustomData.LastHitTarget = TargetEntity
			OnHitCallback(TargetEntity)
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

	if Player then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	end

	local StartTimestamp = os.clock()

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

function AttackBase.ProcessHit(AttackerContext: ActionContext, Target: Entity): boolean
	local TargetContext = ActionExecutor.GetActiveContext(Target)

	if TargetContext and TargetContext.Metadata.ActionName == "Block" then
		local Metadata = AttackerContext.Metadata
		local Damage = Metadata.Damage or 10

		Block.OnHit(TargetContext, AttackerContext.Entity, Damage)

		Ensemble.Events.Publish(CombatEvents.AttackBlocked, {
			Attacker = AttackerContext.Entity,
			Target = Target,
			Damage = Damage,
			AttackerContext = AttackerContext,
			TargetContext = TargetContext,
		})

		return true
	end

	AttackBase.ApplyDamage(AttackerContext, Target)
	AttackBase.ApplyHitStun(AttackerContext, Target)

	Ensemble.Events.Publish(CombatEvents.AttackHit, {
		Entity = AttackerContext.Entity,
		Target = Target,
		Damage = AttackerContext.Metadata.Damage or 10,
		Context = AttackerContext,
	})

	return false
end

function AttackBase.ApplyDamage(Context: ActionContext, Target: Entity)
	local Metadata = Context.Metadata
	local Damage = Metadata.Damage or 10

	local DamageComponent = Target:GetComponent("Damage")
	if not DamageComponent then
		return
	end

	local RootPart = Context.Entity.Character and Context.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local KnockbackDirection = if RootPart then RootPart.CFrame.LookVector else Vector3.zero

	DamageComponent:DealDamage(Damage, Context.Entity.Player, KnockbackDirection)

	Ensemble.Events.Publish(CombatEvents.DamageDealt, {
		Entity = Context.Entity,
		Target = Target,
		Damage = Damage,
		ActionName = Metadata.ActionName,
		Context = Context,
	})
end

function AttackBase.ApplyHitStun(Context: ActionContext, Target: Entity)
	local Metadata = Context.Metadata
	local HitStun = Metadata.HitStun or 0.25

	local StateComponent = Target:GetComponent("States")
	if not StateComponent then
		return
	end

	StateComponent:SetState("Stunned", true)

	Ensemble.Events.Publish(CombatEvents.HitStunApplied, {
		Entity = Context.Entity,
		Target = Target,
		Duration = HitStun,
		Context = Context,
	})

	task.delay(HitStun, function()
		if StateComponent then
			StateComponent:SetState("Stunned", false)
		end

		Ensemble.Events.Publish(CombatEvents.StunEnded, {
			Entity = Target,
			Reason = "HitStunExpired",
		})
	end)
end

function AttackBase.HandleStaminaRefund(Context: ActionContext)
	local Metadata = Context.Metadata
	local StaminaCost = Metadata.StaminaCost or 0
	local RefundRate = Metadata.StaminaCostHitReduction or 0.15

	if not Context.CustomData.HasHit or StaminaCost <= 0 then
		return
	end

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if not StaminaComponent then
		return
	end

	local RefundAmount = StaminaCost * RefundRate
	StaminaComponent:RestoreStaminaExternal(RefundAmount)

	Ensemble.Events.Publish(CombatEvents.StaminaRefunded, {
		Entity = Context.Entity,
		Amount = RefundAmount,
		Reason = "HitRefund",
		Context = Context,
	})
end

function AttackBase.ConsumeStamina(Context: ActionContext): boolean
	local Metadata = Context.Metadata
	local StaminaCost = Metadata.StaminaCost or 0

	if StaminaCost <= 0 then
		return true
	end

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if not StaminaComponent then
		return false
	end

	StaminaComponent:ConsumeStamina(StaminaCost)

	Ensemble.Events.Publish(CombatEvents.StaminaConsumed, {
		Entity = Context.Entity,
		Amount = StaminaCost,
		ActionName = Metadata.ActionName,
		Context = Context,
	})

	return true
end

function AttackBase.CleanupAttack(Context: ActionContext)
	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = false

	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.StopAnimation:FireClient(Player, AnimationId, 0.15)
	end

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Destroy()
		Context.CustomData.ActiveHitbox = nil
	end

	Context.Entity.States:SetState("Attacking", false)
end

return AttackBase