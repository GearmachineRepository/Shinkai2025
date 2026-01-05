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

	THREAD SCHEDULING:
	Use ActionExecutor.ScheduleThread() instead of task.delay() for automatic cleanup:

	ActionExecutor.ScheduleThread(Context, Duration, function()
		-- This callback is automatically cancelled if action is interrupted
	end)

	For threads that MUST run even after interrupt (like state cleanup):
	ActionExecutor.ScheduleThread(Context, Duration, Callback, true)

	WINDOW SYSTEM:
	To open a defensive window during an action:
	ActionExecutor.OpenWindow(Entity, "PerfectGuard")

	To check for window triggers when hit:
	if ActionExecutor.TriggerWindow(Context, Attacker) then return end
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local EntityAnimator = require(script.Parent.Parent.Utility.EntityAnimator)

local ActionValidator = require(Shared.Utility.ActionValidator)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local ActionTemplate = {}

ActionTemplate.ActionName = "ActionTemplate"
ActionTemplate.ActionType = "Attack"

local COOLDOWN_ID = "ActionTemplate"

ActionTemplate.DefaultMetadata = {
	ActionName = "ActionTemplate",
	ActionType = "Attack",
	ActionCooldown = 1.0,
	Damage = 10,
	StaminaCost = 5,
	HitStun = 0.25,
	AnimationId = "DefaultAnimation",
	HitboxSize = Vector3.new(4, 4, 4),
	HitboxOffset = Vector3.new(0, 0, -3),
	Feintable = true,
	FeintEndlag = 0.2,
	FeintCooldown = 0.5,
}

function ActionTemplate.BuildMetadata(_Entity: Entity, _InputData: { [string]: any }?): ActionMetadata?
	local Metadata: ActionMetadata = table.clone(ActionTemplate.DefaultMetadata)
	return Metadata
end

function ActionTemplate.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "ActionTemplate")
	if not CanPerform then
		return false, Reason
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if StatComponent then
		local StaminaCost = Context.Metadata.StaminaCost or 0
		if StatComponent:GetStat("Stamina") < StaminaCost then
			return false, "NoStamina"
		end
	end

	local ActionCooldown = Context.Metadata.ActionCooldown or 0
	if ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown) then
		return false, "OnCooldown"
	end

	return true, nil
end

function ActionTemplate.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.CanFeint = Context.Metadata.Feintable

	Context.Entity.States:SetState("Attacking", true)

	local ActionCooldown = Context.Metadata.ActionCooldown or 0
	if ActionCooldown > 0 then
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown)
	end
end

function ActionTemplate.OnExecute(Context: ActionContext)
	local Player = Context.Entity.Player
	local Character = Context.Entity.Character

	local AnimationId = Context.Metadata.AnimationId

	if AnimationId then
		if Player then
			Packets.PlayAnimation:FireClient(Player, AnimationId)
		elseif Character then
			EntityAnimator.Play(Character, AnimationId)
		end
	end

	Ensemble.Events.Publish(CombatEvents.AttackStarted, {
		Entity = Context.Entity,
		ActionName = "ActionTemplate",
		Context = Context,
	})

	task.wait(1.0)
end

function ActionTemplate.OnHit(Context: ActionContext, Target: Entity, HitPosition: Vector3?, _HitIndex: number?)
	if not Context.CustomData.HitWindowOpen or Context.CustomData.HasHit then
		return
	end

	Context.CustomData.HasHit = true

	local Damage = Context.Metadata.Damage or 10

	Ensemble.Events.Publish(CombatEvents.AttackHit, {
		Entity = Context.Entity,
		Target = Target,
		Damage = Damage,
		HitPosition = HitPosition,
		Context = Context,
	})
end

function ActionTemplate.OnComplete(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.ActionCompleted, {
		Entity = Context.Entity,
		ActionName = "ActionTemplate",
		Context = Context,
	})
end

function ActionTemplate.OnInterrupt(Context: ActionContext)
	if Context.InterruptReason == "Feint" then
		ActionExecutor.ClearCooldown(Context.Entity, COOLDOWN_ID)

		local FeintEndlag = Context.Metadata.FeintEndlag or 0
		if FeintEndlag > 0 then
			task.wait(FeintEndlag)
		end
	end
end

function ActionTemplate.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Attacking", false)
end

return ActionTemplate