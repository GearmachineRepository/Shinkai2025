--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local StunManager = require(script.Parent.Parent.Utility.StunManager)

local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local PerfectGuard = {}

PerfectGuard.ActionName = "PerfectGuard"
PerfectGuard.WindowType = "PerfectGuard"
PerfectGuard.Duration = CombatBalance.PerfectBlock.WINDOW_SECONDS
PerfectGuard.Cooldown = CombatBalance.PerfectBlock.COOLDOWN_SECONDS
PerfectGuard.SpamCooldown = CombatBalance.PerfectBlock.SPAM_COOLDOWN_SECONDS
PerfectGuard.StaggerDuration = CombatBalance.PerfectBlock.STAGGER_DURATION
PerfectGuard.MaxAngle = CombatBalance.PerfectBlock.MAX_ANGLE

local function OnTrigger(Context: ActionContext, Attacker: Entity)
	Ensemble.Events.Publish(CombatEvents.ParrySuccess, {
		Entity = Context.Entity,
		Attacker = Attacker,
		ParryType = "PerfectGuard",
	})

	Ensemble.Events.Publish(CombatEvents.PerfectGuardSuccess, {
		Entity = Context.Entity,
		Target = Attacker,
	})

	StunManager.ApplyStun(Attacker, PerfectGuard.StaggerDuration, "PerfectGuard")

	ActionExecutor.Interrupt(Context.Entity, "PerfectGuard")
end

local function OnExpire(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.ParryFailed, {
		Entity = Context.Entity,
		ParryType = "PerfectGuard",
	})
end

function PerfectGuard.Register()
	ActionExecutor.RegisterWindow({
		WindowType = PerfectGuard.WindowType,
		Duration = PerfectGuard.Duration,
		Cooldown = PerfectGuard.Cooldown,
		SpamCooldown = PerfectGuard.SpamCooldown,
		StateName = "PerfectGuardWindow",
		MaxAngle = PerfectGuard.MaxAngle,
		OnTrigger = OnTrigger,
		OnExpire = OnExpire,
	})
end

return PerfectGuard