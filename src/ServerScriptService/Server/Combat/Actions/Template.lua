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
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local ActionValidator = require(Shared.Utils.ActionValidator)
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
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "M1")
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
	if ActionCooldown > 0 and ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown) then
		return false, "OnCooldown"
	end

	return true, nil
end

function ActionTemplate.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.CanFeint = Context.Metadata.Feintable

	local ActionCooldown = Context.Metadata.ActionCooldown or 0
	if ActionCooldown > 0 then
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown)
	end
end

function ActionTemplate.OnExecute(Context: ActionContext)
	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	end

	Context.Entity.States:SetState("Attacking", true)

	task.wait(0.5)
end

function ActionTemplate.OnHit(Context: ActionContext, Target: Entity, _HitIndex: number)
	if not Context.CustomData.HitWindowOpen then
		return
	end

	local Damage = Context.Metadata.Damage or 10
	local DamageComponent = Target:GetComponent("Damage")
	if DamageComponent then
		DamageComponent:DealDamage(Damage, Context.Entity.Player or Context.Entity.Character, Vector3.zero)
	end

	Ensemble.Events.Publish(CombatEvents.AttackHit, {
		Entity = Context.Entity,
		Target = Target,
		ActionName = Context.Metadata.ActionName,
		Damage = Damage,
		Context = Context,
	})
end

function ActionTemplate.OnComplete(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.ActionCompleted, {
		Entity = Context.Entity,
		ActionName = Context.Metadata.ActionName,
		Context = Context,
	})
end

function ActionTemplate.OnInterrupt(Context: ActionContext)
	if Context.InterruptReason == "Feint" then
		Ensemble.Events.Publish(CombatEvents.FeintExecuted, {
			Entity = Context.Entity,
			ActionName = Context.Metadata.ActionName,
			Context = Context,
		})

		local FeintEndlag = Context.Metadata.FeintEndlag or 0
		if FeintEndlag > 0 then
			task.wait(FeintEndlag)
		end
	end
end

function ActionTemplate.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Attacking", false)

	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.StopAnimation:FireClient(Player, AnimationId, 0.15)
	end
end

return ActionTemplate