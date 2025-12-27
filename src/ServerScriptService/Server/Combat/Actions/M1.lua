--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local CombatTypes = require(Server.Combat.CombatTypes)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local ActionValidator = require(Shared.Utils.ActionValidator)
local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)
local Hitbox = require(Shared.Packages.Hitbox)

type ActionContext = CombatTypes.ActionContext
type Entity = CombatTypes.Entity

local M1 = {}

M1.ActionName = "M1"
M1.ActionType = "Attack"

M1.DefaultMetadata = {
	ActionName = "M1",
	AnimationSet = "Karate",
	FeintEndlag = 0.25,
	FeintCooldown = 3.0,
	ComboEndlag = 0.5,
	HitStun = 0.25,
	StaminaCost = 5,
	StaminaCostHitReduction = 0.50,
	Feintable = true,

	FallbackTimings = {
		HitStart = 0.25,
		HitEnd = 0.55,
		Length = 1.25,
	},
}

function M1.CanExecute(Context: ActionContext): (boolean, string?)
	if not Context or not Context.Metadata or not Context.Entity then
		return false, "InvalidContext"
	end

	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "M1")
	if not CanPerform then
		return false, Reason
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if not StatComponent then
		return false, "NoStatComponent"
	end

	local StaminaCost = Context.Metadata.StaminaCost :: number
	if StatComponent:GetStat("Stamina") < StaminaCost then
		return false, "NoStamina"
	end

	return true, nil
end

function M1.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.LastHitTarget = nil
	Context.CustomData.CanFeint = true

	local Metadata = Context.Metadata
	if not Metadata then
		return
	end

	local RootPart = Context.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not RootPart then
		return
	end

	local HitboxSize: Vector3 = Metadata.HitboxSize or Vector3.new(4, 4, 4)
	local HitboxOffset: CFrame = Metadata.HitboxOffset or CFrame.new(0, 0, -3)

	local NewHitbox = Hitbox.new({
		SizeOrPart = HitboxSize,
		InitialCframe = RootPart.CFrame * HitboxOffset,
		VelocityPrediction = true,
		Debug = false,
		LifeTime = 0,
		LookingFor = "Humanoid",
		Blacklist = { Context.Entity.Character },
		DebounceTime = 0,
		SpatialOption = "InBox",
	})

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
			M1.OnHit(Context, TargetEntity, 1)
			break
		end
	end)

	Context.CustomData.ActiveHitbox = NewHitbox
end

function M1.OnExecute(Context: ActionContext)
	local Metadata = Context.Metadata
	if not Metadata then
		return
	end

	local AttackData = Context.CustomData.AttackData
	if not AttackData then
		warn("[M1] No AttackData in CustomData")
		return
	end

	local AnimationName = AttackData.AnimationId

	if Context.Entity.Player then
		Packets.PlayAnimation:FireClient(Context.Entity.Player, Context.CustomData.AttackData.AnimationId)
	end

	local AnimationLength = AnimationTimingCache.GetLength(AnimationName) or Metadata.FallbackTimings.Length
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationName, "HitStart", Metadata.FallbackTimings.HitStart)
	local HitEndTime = AnimationTimingCache.GetTiming(AnimationName, "HitStop", Metadata.FallbackTimings.HitEnd)

	Context.Entity.States:SetState("Attacking", true)

	if not AnimationLength or not HitStartTime or not HitEndTime then
		return
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
		-- Feinted/interrupted before hit window
		if Context.Entity.Player then
			Packets.StopAnimation:FireClient(Context.Entity.Player, Context.CustomData.AttackData.AnimationId, 0.25)
		end
		return
	end

	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = true

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Start()
	end

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if not StaminaComponent then
		M1.OnCleanup(Context)
		return
	end

	local StaminaCost = Metadata.StaminaCost :: number
	StaminaComponent:ConsumeStamina(StaminaCost)

	if not WaitUntil(HitEndTime) then
		return
	end

	Context.CustomData.HitWindowOpen = false

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Stop()
	end

	if Context.CustomData.HasHit then
		local Reduction = StaminaCost * Metadata.StaminaCostHitReduction
		StaminaComponent:RestoreStaminaExternal(Reduction)
	end

	WaitUntil(AnimationLength)
end

function M1.OnHit(Context: ActionContext, Target: Entity, _HitIndex: number)
	if not Context or not Context.Metadata then
		return
	end
	if not Context.CustomData.HitWindowOpen then
		return
	end

	local DamageComponent = Target:GetComponent("Damage")
	if DamageComponent then
		local RootPart = Context.Entity.Character and Context.Entity.Character.PrimaryPart
		if RootPart then
			local Damage = Context.Metadata.BaseDamage or Context.Metadata.Damage or 10
			DamageComponent:DealDamage(Damage, Context.Entity.Player, RootPart.CFrame.LookVector)
		end
	end

	local StateComponent = Target:GetComponent("States")
	if StateComponent then
		StateComponent:SetState("Stunned", true)
		task.delay(Context.Metadata.HitStun, function()
			StateComponent:SetState("Stunned", false)
		end)
	end
end

function M1.OnComplete(Context: ActionContext)
	if not Context or not Context.Metadata then
		return
	end

	local AnimationSetName = Context.CustomData.AnimationSetName or Context.Metadata.AnimationSet
	local CurrentCombo = ActionExecutor.GetComboCount(Context.Entity)
	local ComboLength = AnimationSets.GetComboLength(AnimationSetName or "Karate")

	if CurrentCombo == ComboLength and Context.Metadata.ComboEndlag then
		task.wait(Context.Metadata.ComboEndlag)
	end

	ActionExecutor.IncrementCombo(Context.Entity, AnimationSetName)
end

function M1.OnCleanup(Context: ActionContext)
	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = false

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Destroy()
		Context.CustomData.ActiveHitbox = nil
	end
end

return M1
