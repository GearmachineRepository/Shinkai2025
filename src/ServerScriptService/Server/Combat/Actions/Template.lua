--!strict
--[[
	Action Template

	Copy this file and rename it to create a new action.
	Fill in the required fields and implement the lifecycle methods.

	LIFECYCLE ORDER:
	1. BuildMetadata (optional) - Build action metadata from entity/input
	2. CanExecute (optional) - Validate if action can be performed
	3. OnStart (optional) - Setup before execution begins
	4. OnExecute (required) - Main action logic
	5. OnHit (optional) - Called when action hits a target
	6. OnComplete (optional) - Called on successful completion
	7. OnInterrupt (optional) - Called when action is interrupted
	8. OnCleanup (optional) - Always called for cleanup (regardless of completion/interrupt)

	REQUIRES ACTIVE ACTION:
	Set RequiresActiveAction = true for actions that interrupt another action.
	These actions receive Context.InterruptedContext with the replaced action's context.
	Examples: Feint (interrupts attack), PerfectGuard/Counter (interrupt block)

	ACTION TYPES:
	- "Attack" - Offensive actions (LightAttack, HeavyAttack, Counter)
	- "Defensive" - Protective actions (Block, PerfectGuard, Parry)
	- "Movement" - Movement-based actions (Dodge, Dash)
	- "Utility" - Support actions (Feint, Taunt)

	METADATA BUILDERS:
	Use MetadataBuilders for common patterns:
	- MetadataBuilders.ComboAttack("M1", "ActionName") - For combo-based attacks
	- MetadataBuilders.SingleAttack("M2", "ActionName") - For single attacks
	- MetadataBuilders.CounterAttack("ActionName", multiplier) - For counter attacks
	- MetadataBuilders.Static(metadata) - For static metadata
	- MetadataBuilders.Extend(builder, extensions) - To extend existing builders

	THREAD SCHEDULING:
	Use ActionExecutor.ScheduleThread() instead of task.delay() for automatic cleanup:

	ActionExecutor.ScheduleThread(Context, Duration, function()
		-- This callback is automatically cancelled if action is interrupted
	end)

	For threads that MUST run even after interrupt (like state cleanup):
	ActionExecutor.ScheduleThread(Context, Duration, Callback, true)

	ANIMATION:
	Use CombatAnimator for unified player/NPC animation handling:
	- CombatAnimator.Play(Entity, AnimationId)
	- CombatAnimator.Stop(Entity, AnimationId, FadeTime)
	- CombatAnimator.Pause(Entity, AnimationId, Duration)

	STYLE RESOLUTION:
	Use StyleResolver to get equipped style info:
	- StyleResolver.GetEntityStyle(Entity, InputData)
	- StyleResolver.GetEntityStyleOrDefault(Entity, InputData)
	- StyleResolver.GetAttackData(Entity, ComboKey, ComboIndex, InputData)
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local MetadataBuilders = require(script.Parent.Parent.Core.MetadataBuilders)
local CombatAnimator = require(script.Parent.Parent.Utility.CombatAnimator)
local _StyleResolver = require(script.Parent.Parent.Utility.StyleResolver)

local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local ActionTemplate = {}

ActionTemplate.ActionName = "ActionTemplate"
ActionTemplate.ActionType = "Attack"

local COOLDOWN_ID = "ActionTemplate"

ActionTemplate.BuildMetadata = MetadataBuilders.SingleAttack("M2", "ActionTemplate")

function ActionTemplate.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "ActionTemplate")
	if not CanPerform then
		return false, Reason
	end

	local CooldownSeconds = Context.Metadata.ActionCooldown or 0
	if CooldownSeconds > 0 and ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, CooldownSeconds) then
		return false, "OnCooldown"
	end

	return true, nil
end

function ActionTemplate.OnStart(Context: ActionContext)
	Context.Entity.States:SetState("Attacking", true)
end

function ActionTemplate.OnExecute(Context: ActionContext)
	local AnimationId = Context.Metadata.AnimationId
	if AnimationId then
		CombatAnimator.Play(Context.Entity, AnimationId)
	end

	Ensemble.Events.Publish(CombatEvents.AttackStarted, {
		Entity = Context.Entity,
		ActionName = "ActionTemplate",
		Context = Context,
	})

	task.wait(1)
end

function ActionTemplate.OnHit(_Context: ActionContext, _Target: Entity, _HitPosition: Vector3?, _HitIndex: number?)
end

function ActionTemplate.OnComplete(Context: ActionContext)
	local CooldownSeconds = Context.Metadata.ActionCooldown or 0
	if CooldownSeconds > 0 then
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, CooldownSeconds)
	end
end

function ActionTemplate.OnInterrupt(Context: ActionContext)
	local AnimationId = Context.Metadata.AnimationId
	if AnimationId then
		CombatAnimator.Stop(Context.Entity, AnimationId, 0.15)
	end
end

function ActionTemplate.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Attacking", false)
end

return ActionTemplate