--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local WindowManager = require(script.Parent.Parent.Core.WindowManager)
local MetadataBuilders = require(script.Parent.Parent.Core.MetadataBuilders)
local StunManager = require(script.Parent.Parent.Utility.StunManager)
local KnockbackManager = require(script.Parent.Parent.Utility.KnockbackManager)
local AnimationTimingCache = require(script.Parent.Parent.Utility.AnimationTimingCache)
local CombatAnimator = require(script.Parent.Parent.Utility.CombatAnimator)

local CombatBalance = require(Shared.Config.Balance.CombatBalance)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local Counter = {}

Counter.ActionName = "Counter"
Counter.WindowType = "Counter"
Counter.Duration = CombatBalance.Counter.WindowSeconds
Counter.Cooldown = CombatBalance.Counter.CooldownSeconds
Counter.SpamCooldown = CombatBalance.Counter.SpamCooldownSeconds
Counter.StaggerDuration = CombatBalance.Counter.StaggerDuration
Counter.MaxAngle = CombatBalance.Counter.MaxAngle

local DAMAGE_MULTIPLIER = 1.0

local GetCounterData = MetadataBuilders.CounterAttack("Counter", DAMAGE_MULTIPLIER)

local function ExecuteCounterAttack(Entity: Entity, Attacker: Entity)
	local CounterData = GetCounterData(Entity, nil)
	if not CounterData then
		return
	end

	Entity.States:SetState("Attacking", true)

	local AnimationId = CounterData.AnimationId
	if not AnimationId then return end

	CombatAnimator.Play(Entity, AnimationId)

	local AnimationLength = AnimationTimingCache.GetLength(AnimationId) or CounterData.FallbackLength or 1.0  :: number
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationId, "HitStart", CounterData.FallbackHitStart or 0.2) :: number

	task.spawn(function()
		task.wait(HitStartTime)

		local Damage = CounterData.Damage or 10

		local DamageComponent = Attacker:GetComponent("Damage")
		if DamageComponent then
			DamageComponent:DealDamage(Damage, Entity.Player or Entity.Character)
		end

		StunManager.ApplyStun(Attacker, CounterData.HitStun or 0.4, "Counter")

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
	WindowManager.Register({
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