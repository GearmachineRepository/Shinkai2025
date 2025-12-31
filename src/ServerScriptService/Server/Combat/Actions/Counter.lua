--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local StunManager = require(script.Parent.Parent.Utility.StunManager)
local AnimationTimingCache = require(script.Parent.Parent.Utility.AnimationTimingCache)
local KnockbackManager = require(script.Parent.Parent.Utility.KnockbackManager)

local EntityAnimator = require(Server.Ensemble.Utilities.EntityAnimator)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local Counter = {}

Counter.ActionName = "Counter"
Counter.WindowType = "Counter"
Counter.Duration = CombatBalance.Counter.WINDOW_SECONDS
Counter.Cooldown = CombatBalance.Counter.COOLDOWN_SECONDS
Counter.SpamCooldown = CombatBalance.Counter.SPAM_COOLDOWN_SECONDS
Counter.StaggerDuration = CombatBalance.Counter.STAGGER_DURATION
Counter.MaxAngle = CombatBalance.Counter.MAX_ANGLE

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

	local AnimationSetName = "Fists"
	if ItemId then
		local ItemData = ItemDatabase.GetItem(ItemId)
		if ItemData and ItemData.AnimationSet then
			AnimationSetName = ItemData.AnimationSet
		end
	end

	local AnimationSet = AnimationSets.Get(AnimationSetName) or AnimationSets.Get("Fists")
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

	local SetMetadata = AnimationSets.GetMetadata(AnimationSetName)

	return {
		AnimationId = LastM1Data.AnimationId,
		Damage = math.floor((LastM1Data.Damage or 10) * DAMAGE_MULTIPLIER),
		HitStun = LastM1Data.HitStun or 0.4,
		Knockback = LastM1Data.Knockback or 40,
		HitboxSize = LastM1Data.Hitbox and LastM1Data.Hitbox.Size or Vector3.new(6, 5, 7),
		HitboxOffset = LastM1Data.Hitbox and LastM1Data.Hitbox.Offset or Vector3.new(0, 0, -4),
		FallbackHitStart = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.HitStart or 0.2,
		FallbackHitEnd = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.HitEnd or 0.5,
		FallbackLength = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.Length or 1.0,
	}
end

local function ExecuteCounterAttack(Entity: Entity, Attacker: Entity)
	local CounterData = GetCounterData(Entity)
	if not CounterData then
		return
	end

	Entity.States:SetState("Attacking", true)

	local Player = Entity.Player
	local Character = Entity.Character
	local AnimationId = CounterData.AnimationId

	if AnimationId then
		if Player then
			Packets.PlayAnimation:FireClient(Player, AnimationId)
		elseif Character then
			EntityAnimator.Play(Character, AnimationId)
		end
	end

	local AnimationLength = AnimationTimingCache.GetLength(AnimationId) or CounterData.FallbackLength
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationId, "HitStart", CounterData.FallbackHitStart)

	task.spawn(function()
		task.wait(HitStartTime)

		local Damage = CounterData.Damage

		local DamageComponent = Attacker:GetComponent("Damage")
		if DamageComponent then
			DamageComponent:DealDamage(Damage, Entity.Player or Entity.Character)
		end

		StunManager.ApplyStun(Attacker, CounterData.HitStun, "Counter")

		local Knockback = CounterData.Knockback
		if Knockback and Knockback > 0 then
			KnockbackManager.Apply(Attacker, Entity, Knockback)
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

local function OnTrigger(Context: ActionContext, Attacker: Entity)
	Ensemble.Events.Publish(CombatEvents.CounterExecuted, {
		Entity = Context.Entity,
		Attacker = Attacker,
	})

	ExecuteCounterAttack(Context.Entity, Attacker)

	ActionExecutor.Interrupt(Context.Entity, "Counter")
end

local function OnExpire(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.ParryFailed, {
		Entity = Context.Entity,
		ParryType = "Counter",
	})
end

function Counter.Register()
	ActionExecutor.RegisterWindow({
		WindowType = Counter.WindowType,
		Duration = Counter.Duration,
		Cooldown = Counter.Cooldown,
		SpamCooldown = Counter.SpamCooldown,
		StateName = "CounterWindow",
		MaxAngle = Counter.MaxAngle,
		OnTrigger = OnTrigger,
		OnExpire = OnExpire,
	})
end

return Counter