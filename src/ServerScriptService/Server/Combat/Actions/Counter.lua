--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local Counter = {}

Counter.WindowDuration = CombatBalance.Counter.WINDOW_SECONDS
Counter.SpamCooldown = CombatBalance.Counter.SPAM_COOLDOWN_SECONDS
Counter.Cooldown = CombatBalance.Counter.COOLDOWN_SECONDS

local COOLDOWN_ID = "Counter"
local DEFAULT_KNOCKBACK_FORCE = 50
local DAMAGE_MULTIPLIER = 0.8

local function GetCounterData(Entity: Entity): { [string]: any }?
	local ToolComponent = Entity:GetComponent("Tool")
	local ItemId = nil

	if ToolComponent then
		local EquippedTool = ToolComponent:GetEquippedTool()
		if EquippedTool and EquippedTool.ToolId then
			ItemId = EquippedTool.ToolId
		end
	end

	local AnimationSetName = "Unarmed"
	if ItemId then
		local ItemData = ItemDatabase.GetItem(ItemId)
		if ItemData and ItemData.AnimationSet then
			AnimationSetName = ItemData.AnimationSet
		end
	end

	local AnimationSet = AnimationSets[AnimationSetName] or AnimationSets["Unarmed"]
	if not AnimationSet then
		return nil
	end

	local M1Table = AnimationSet.M1
	if not M1Table then
		return nil
	end

	local LastIndex = #M1Table
	local LastM1Data = M1Table[LastIndex]
	if not LastM1Data then
		return nil
	end

	local SetMetadata = AnimationSet.Metadata or {}

	return {
		AnimationId = LastM1Data.AnimationId,
		Damage = math.floor((LastM1Data.Damage or 10) * DAMAGE_MULTIPLIER),
		HitStun = LastM1Data.HitStun or 0.4,
		HitboxSize = LastM1Data.Hitbox and LastM1Data.Hitbox.Size or Vector3.new(6, 5, 7),
		HitboxOffset = LastM1Data.Hitbox and LastM1Data.Hitbox.Offset or Vector3.new(0, 0, -4),
		FallbackHitStart = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.HitStart or 0.2,
		FallbackHitEnd = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.HitEnd or 0.5,
		FallbackLength = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.Length or 1.0,
	}
end

function Counter.Trigger(BlockContext: ActionContext, Attacker: Entity)
	local Entity = BlockContext.Entity
	local CounterData = GetCounterData(Entity)

	if not CounterData then
		return
	end

	ActionExecutor.StartCooldown(Entity, COOLDOWN_ID, Counter.Cooldown)

	if Entity.Player then
		Packets.StartCooldown:FireClient(Entity.Player, COOLDOWN_ID, Counter.Cooldown, workspace:GetServerTimeNow())
	end

	Ensemble.Events.Publish(CombatEvents.CounterExecuted, {
		Entity = Entity,
		Attacker = Attacker,
	})

	Entity.States:SetState("Blocking", false)
	Entity.States:SetState("Attacking", true)

	local Player = Entity.Player
	local AnimationId = CounterData.AnimationId

	if Player and AnimationId then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	end

	local AnimationLength = AnimationTimingCache.GetLength(AnimationId) or CounterData.FallbackLength
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationId, "HitStart", CounterData.FallbackHitStart)
	local _HitEndTime = AnimationTimingCache.GetTiming(AnimationId, "HitStop", CounterData.FallbackHitEnd)

	task.spawn(function()
		task.wait(HitStartTime)

		local Damage = CounterData.Damage
		local KnockbackForce = DEFAULT_KNOCKBACK_FORCE

		local DamageComponent = Attacker:GetComponent("Damage")
		if DamageComponent then
			local RootPart = Entity.Character and Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local KnockbackDirection = if RootPart then RootPart.CFrame.LookVector else Vector3.zero

			DamageComponent:DealDamage(Damage, Entity.Player, KnockbackDirection)

			local TargetRootPart = Attacker.Character and Attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if TargetRootPart then
				local KnockbackVelocity = KnockbackDirection * KnockbackForce + Vector3.new(0, KnockbackForce * 0.3, 0)
				TargetRootPart.AssemblyLinearVelocity = KnockbackVelocity
			end
		end

		local AttackerStates = Attacker.States
		if AttackerStates then
			AttackerStates:SetState("Stunned", true)

			task.delay(CounterData.HitStun, function()
				if AttackerStates then
					AttackerStates:SetState("Stunned", false)
				end
			end)
		end

		Ensemble.Events.Publish(CombatEvents.CounterHit, {
			Entity = Entity,
			Target = Attacker,
			Damage = Damage,
		})

		Ensemble.Events.Publish(CombatEvents.DamageDealt, {
			Entity = Entity,
			Target = Attacker,
			Damage = Damage,
			ActionName = "Counter",
		})

		task.wait(AnimationLength - HitStartTime)

		Entity.States:SetState("Attacking", false)
	end)
end

return Counter