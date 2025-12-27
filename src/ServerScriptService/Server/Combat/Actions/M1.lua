--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local CombatTypes = require(Server.Combat.CombatTypes)
local Packets = require(Shared.Networking.Packets)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local Ensemble = require(ServerScriptService.Server.Ensemble)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local Hitbox = require(Shared.Packages.Hitbox)

type ActionContext = CombatTypes.ActionContext
type Entity = CombatTypes.Entity
type ActionMetadata = CombatTypes.ActionMetadata

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
	Feintable = true,

	FallbackTimings = {
		HitStart = 0.25,
		HitEnd = 0.55,
		Length = 1.25
	},
}

function M1.CanExecute(Context: ActionContext): (boolean, string?)
	if not Context then
		return false, "Missing context"
	end

	if not Context.Metadata then
		return false, "Missing metadata"
	end

	if not Context.Entity then
		return false, "Missing entity"
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if not StatComponent then return false, "No StatComponent" end
	local StateComponent = Context.Entity:GetComponent("States")
	if not StateComponent then return false, "No StateComponent" end

	local StaminaCost = Context.Metadata.StaminaCost :: number
	if StatComponent:GetStat("Stamina") <= 0 or StatComponent:GetStat("Stamina") - StaminaCost < 0 then
		return false, "No stamina"
	end

	if StateComponent:GetState("Exhausted") then
		return false, "Exhausted"
	end

	if StateComponent:GetState("Stunned") then
		return false, "Stunned"
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

	local ItemId = Context.InputData and Context.InputData.ItemId
	if ItemId then
		local ItemData = ItemDatabase.GetItem(ItemId)
		if ItemData and ItemData.BaseStats then
			for Key, Value in ItemData.BaseStats do
				Metadata[Key] = Value
			end

			if ItemData.AnimationSet then
				Metadata.AnimationSet = ItemData.AnimationSet
			end
		end
	end

	local AnimationSetName = Metadata.AnimationSet or "Karate"
	local ComboCount = ActionExecutor.GetComboCount(Context.Entity)

	local AttackData = AnimationSets.GetAttack(AnimationSetName, ComboCount)
	if not AttackData then
		warn("Failed to get attack data for set:", AnimationSetName, "index:", ComboCount)
		return
	end

	Context.CustomData.ComboCount = ComboCount
	Context.CustomData.AttackData = AttackData
	Context.CustomData.AnimationSetName = AnimationSetName

	if not Metadata.BaseDamage then
		Metadata.BaseDamage = AttackData.Damage
	end
	if not Metadata.StaminaCost then
		Metadata.StaminaCost = AttackData.StaminaCost
	end
	if not Metadata.HitboxSize then
		Metadata.HitboxSize = AttackData.Hitbox.Size
	end
	if not Metadata.HitboxOffset then
		Metadata.HitboxOffset = CFrame.new(AttackData.Hitbox.Offset)
	end

	local RootPart = Context.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart
	if not RootPart then
		return
	end

	local HitboxSize: Vector3 = Metadata.HitboxSize or error("Metadata.HitboxSize is required")
	local HitboxOffset: CFrame = Metadata.HitboxOffset or CFrame.new()

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

	NewHitbox:WeldTo(RootPart, Metadata.HitboxOffset)

	NewHitbox.OnHit:Connect(function(HitCharacters: { Model })
		if not Context.CustomData.HitWindowOpen then
			return
		end

		for _, TargetCharacter in HitCharacters do
			if Context.CustomData.HasHit then
				return
			end

			local TargetEntity = Ensemble.GetEntity(TargetCharacter)
			if not TargetEntity then
				continue
			end

			if TargetEntity == Context.Entity then
				continue
			end

			Context.CustomData.HasHit = true
			Context.CustomData.LastHitTarget = TargetEntity

			if M1.OnHit then
				M1.OnHit(Context, TargetEntity, 1)
			end
		end
	end)

	Context.CustomData.ActiveHitbox = NewHitbox
end

function M1.Feinted(Context: ActionContext, AnimationName: string)
	if Context.Entity.Player then
		Packets.StopAnimation:FireClient(Context.Entity.Player, AnimationName, 0.15)
	end
end

function M1.OnExecute(Context: ActionContext)
	local Metadata = Context.Metadata
	if Metadata == nil then
		return
	end

	local AttackData = Context.CustomData.AttackData
	if not AttackData then
		warn("No AttackData in CustomData")
		return
	end

	local AnimationName = AttackData.AnimationId

	if Context.Entity.Player then
		Packets.PlayAnimation:FireClient(Context.Entity.Player, AnimationName)
	end

	local AnimationLength = AnimationTimingCache.GetLength(AnimationName) or Metadata.FallbackTimings.Length
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationName, "HitStart", Metadata.FallbackTimings.HitStart)
	local HitEndTime = AnimationTimingCache.GetTiming(AnimationName, "HitStop", Metadata.FallbackTimings.HitEnd)

	Context.Entity.States:SetState("Attacking", true)

	if not AnimationLength or not HitStartTime or not HitEndTime then
		return
	end

	local StartTimestamp = os.clock()

	local function WaitUntil(AbsoluteSecondsFromStart: number): boolean
		local Elapsed = os.clock() - StartTimestamp
		local Remaining = AbsoluteSecondsFromStart - Elapsed
		if Remaining > 0 then
			task.wait(Remaining)
		end
		return Context.Interrupted ~= true
	end

	if not WaitUntil(HitStartTime) then
		M1.Feinted(Context, AnimationName)
		return
	end

	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = true

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Start()
	end

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent then
		StaminaComponent:ConsumeStamina(Metadata.StaminaCost)
	end

	if not WaitUntil(HitEndTime) then
		return
	end

	Context.CustomData.HitWindowOpen = false

	if Context.CustomData.ActiveHitbox then
		Context.CustomData.ActiveHitbox:Stop()
	end

	if not WaitUntil(AnimationLength) then
		return
	end
end

function M1.OnHit(Context: ActionContext, Target: Entity, HitIndex: number)
	if not Context or not Context.Metadata then return end
	if not Context.CustomData.HitWindowOpen then
		return
	end

	local DamageComponent = Target:GetComponent("Damage")
	if DamageComponent then
		if not Context.Entity.Character or not Context.Entity.Character.PrimaryPart then return end
		DamageComponent:DealDamage(Context.Metadata.BaseDamage or Context.Metadata.Damage, Context.Entity.Player, Context.Entity.Character.PrimaryPart.CFrame.LookVector)
	end

	local StateComponent = Target:GetComponent("States")
	if StateComponent then
		StateComponent:SetState("Stunned", true)
		task.delay(Context.Metadata.HitStun, function()
			StateComponent:SetState("Stunned", false)
		end)
	end

	Context.CustomData.HasHit = true
	Context.CustomData.LastHitTarget = Target
	Context.CustomData.LastHitIndex = HitIndex
end

function M1.OnComplete(Context: ActionContext)
	if not Context or not Context.Metadata then return end
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