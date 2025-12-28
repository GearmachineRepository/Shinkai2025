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

local M2 = {}

M2.ActionName = "M2"
M2.ActionType = "Attack"

function M2.CanExecute(Context: ActionContext): (boolean, string?)
	if not Context.Metadata then
		return false, "NoMetadata"
	end

	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "M2")
	if not CanPerform then
		return false, Reason
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if not StatComponent then
		return false, "NoStatComponent"
	end

	if StatComponent:GetStat("Stamina") < Context.Metadata.StaminaCost then
		return false, "NoStamina"
	end

	return true, nil
end

function M2.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.LastHitTarget = nil
	Context.CustomData.CanFeint = true

	local RootPart = Context.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not RootPart then
		return
	end

	local HitboxSize = Context.Metadata.HitboxSize
	local HitboxOffset = CFrame.new(Context.Metadata.HitboxOffset)

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
			M2.OnHit(Context, TargetEntity, 1)
			break
		end
	end)

	Context.CustomData.ActiveHitbox = NewHitbox
end

function M2.OnExecute(Context: ActionContext)
	local Player = Context.Entity.Player
	if not Player then return end

	local Metadata = Context.Metadata

	local AnimationName = Metadata.AnimationId
	local AnimationLength = AnimationTimingCache.GetLength(AnimationName) or Metadata.FallbackLength
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationName, "HitStart", Metadata.FallbackHitStart)
	local HitEndTime = AnimationTimingCache.GetTiming(AnimationName, "HitStop", Metadata.FallbackHitEnd)

	local StaminaComponent = Context.Entity:GetComponent("Stamina")

	if not StaminaComponent then return end
	if not HitStartTime or not HitEndTime then return end

	Context.Entity.States:SetState("Attacking", true)

	Packets.PlayAnimation:FireClient(Player, AnimationName)

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

	local StaminaCost = Metadata.StaminaCost :: number

	StaminaComponent:ConsumeStamina(StaminaCost)

	if not WaitUntil(HitEndTime) then
		Packets.StopAnimation:FireClient(Player, AnimationName, 0.1)
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

	if not WaitUntil(AnimationLength) then
		return
	end

	Context.Entity.States:SetState("Attacking", false)
end

function M2.OnHit(Context: ActionContext, Target: Entity, _HitIndex: number)
	local Metadata = Context.Metadata

	local DamageComponent = Target:GetComponent("Damage")
	if DamageComponent then
		local RootPart = Context.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart
		if RootPart then
			DamageComponent:DealDamage(Metadata.Damage, Context.Entity.Player, RootPart.CFrame.LookVector)
		end
	end

	local StateComponent = Target:GetComponent("States")
	if StateComponent then
		StateComponent:SetState("Stunned", true)
		task.delay(Metadata.HitStun, function()
			StateComponent:SetState("Stunned", false)
		end)
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if StatComponent then
		local StaminaRefund = Metadata.StaminaCost * Metadata.StaminaCostHitReduction
		StatComponent:ModifyStat("Stamina", StaminaRefund)
	end
end

function M2.OnComplete(Context: ActionContext)
	local Metadata = Context.Metadata
	local ComboLength = AnimationSets.GetComboLength(Metadata.AnimationSet, Metadata.ActionName)

	ActionExecutor.SetCombo(Context.Entity, Metadata.ComboCount, ComboLength)

	if Metadata.ComboCount == ComboLength and Metadata.ComboEndlag > 0 then
		task.wait(Metadata.ComboEndlag)
	end
end

function M2.OnInterrupt(Context: ActionContext)
	if Context.InterruptReason == "Feint" and Context.Metadata.FeintEndlag > 0 then
		task.wait(Context.Metadata.FeintEndlag)
	end
end

function M2.OnCleanup(Context: ActionContext)
	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = false

	if Context and Context.Metadata and Context.Entity.Player then
		Packets.StopAnimation:FireClient(Context.Entity.Player, Context.Metadata.AnimationId, 0.15)
	end

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Destroy()
		Context.CustomData.ActiveHitbox = nil
	end

	Context.Entity.States:SetState("Attacking", false)
end

return M2