--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local WindowManager = require(script.Parent.Parent.Core.WindowManager)
local StunManager = require(script.Parent.Parent.Utility.StunManager)
local CombatAnimator = require(script.Parent.Parent.Utility.CombatAnimator)

local CombatBalance = require(Shared.Config.Balance.CombatBalance)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext

local PerfectGuard = {}

PerfectGuard.ActionName = "PerfectGuard"
PerfectGuard.WindowType = "PerfectGuard"
PerfectGuard.Duration = CombatBalance.PerfectBlock.WindowSeconds
PerfectGuard.Cooldown = CombatBalance.PerfectBlock.CooldownSeconds
PerfectGuard.SpamCooldown = CombatBalance.PerfectBlock.SpamCooldownSeconds
PerfectGuard.StaggerDuration = CombatBalance.PerfectBlock.StaggerDuration
PerfectGuard.MaxAngle = CombatBalance.PerfectBlock.MaxAngle

local STAGGER_PAUSE_DIVISOR = 1.5

local function OnTrigger(Context: ActionContext, Attacker: Entity)
	local AttackerContext = ActionExecutor.GetActiveContext(Attacker)
	local AttackerAnimationId = AttackerContext and AttackerContext.Metadata.AnimationId

	if AttackerAnimationId then
		local PauseDuration = PerfectGuard.StaggerDuration / STAGGER_PAUSE_DIVISOR
		CombatAnimator.Pause(Attacker, AttackerAnimationId, PauseDuration)

		task.delay(PerfectGuard.StaggerDuration, function()
			CombatAnimator.Stop(Attacker, AttackerAnimationId, 0.15)
		end)
	end

	Ensemble.Events.Publish(CombatEvents.ParrySuccess, {
		Entity = Context.Entity,
		Attacker = Attacker,
		ParryType = "PerfectGuard",
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
	WindowManager.Register({
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