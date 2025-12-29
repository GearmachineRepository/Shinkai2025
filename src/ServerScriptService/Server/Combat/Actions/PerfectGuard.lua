--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local StunManager = require(Server.Combat.StunManager)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local PerfectGuard = {}

PerfectGuard.ActionName = "PerfectGuard"
PerfectGuard.WindowDuration = CombatBalance.PerfectBlock.WINDOW_SECONDS
PerfectGuard.Cooldown = CombatBalance.PerfectBlock.COOLDOWN_SECONDS
PerfectGuard.SpamCooldown = CombatBalance.PerfectBlock.SPAM_COOLDOWN_SECONDS
PerfectGuard.StaggerDuration = CombatBalance.PerfectBlock.STAGGER_DURATION

local COOLDOWN_ID = "PerfectGuard"

function PerfectGuard.Trigger(BlockContext: ActionContext, Attacker: Entity)
	local Entity = BlockContext.Entity

	ActionExecutor.StartCooldown(Entity, COOLDOWN_ID, PerfectGuard.Cooldown)

	Ensemble.Events.Publish(CombatEvents.ParrySuccess, {
		Entity = Entity,
		Attacker = Attacker,
		ParryType = "PerfectGuard",
	})

	Ensemble.Events.Publish(CombatEvents.PerfectGuardSuccess, {
		Entity = Entity,
		Target = Attacker,
	})

	local AttackerStates = Attacker.States
	if AttackerStates then
		StunManager.ApplyStun(Attacker, PerfectGuard.StaggerDuration, "PerfectGuard")
	end
end

return PerfectGuard