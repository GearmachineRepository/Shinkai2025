--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)

local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local Feint = {}

Feint.ActionName = "Feint"
Feint.ActionType = "Utility"
Feint.RequiresActiveAction = true

local COOLDOWN_ID = "Feint"
local DEFAULT_COOLDOWN = 0.5
local DEFAULT_ENDLAG = 0.2

function Feint.BuildMetadata(Entity: Entity, _InputData: { [string]: any }?): ActionMetadata?
	local ActiveContext = ActionExecutor.GetActiveContext(Entity)
	if not ActiveContext then
		return nil
	end

	return {
		ActionName = "Feint",
		ActionType = "Utility",
		FeintCooldown = ActiveContext.Metadata.FeintCooldown or DEFAULT_COOLDOWN,
		FeintEndlag = ActiveContext.Metadata.FeintEndlag or DEFAULT_ENDLAG,
	}
end

function Feint.CanExecute(Context: ActionContext): (boolean, string?)
	local Entity = Context.Entity
	local InterruptedContext = Context.InterruptedContext

	local CanPerform, Reason = ActionValidator.CanPerform(Entity.States, "Feint")
	if not CanPerform then
		return false, Reason
	end

	if not InterruptedContext then
		return false, "NoActiveAction"
	end

	if not InterruptedContext.CustomData.CanFeint then
		return false, "NotInFeintWindow"
	end

	if not InterruptedContext.Metadata.Feintable then
		return false, "ActionNotFeintable"
	end

	local FeintCooldown = Context.Metadata.FeintCooldown or DEFAULT_COOLDOWN
	if ActionExecutor.IsOnCooldown(Entity, COOLDOWN_ID, FeintCooldown) then
		return false, "OnCooldown"
	end

	return true, nil
end

function Feint.OnStart(Context: ActionContext)
	local FeintCooldown = Context.Metadata.FeintCooldown or DEFAULT_COOLDOWN
	ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, FeintCooldown)
end

function Feint.OnExecute(Context: ActionContext)
	local InterruptedContext = Context.InterruptedContext
	local SourceAction = InterruptedContext and InterruptedContext.Metadata.ActionName or "Unknown"

	Ensemble.Events.Publish(CombatEvents.FeintExecuted, {
		Entity = Context.Entity,
		SourceAction = SourceAction,
		Context = Context,
	})

	local FeintEndlag = Context.Metadata.FeintEndlag or DEFAULT_ENDLAG
	if FeintEndlag > 0 then
		task.wait(FeintEndlag)
	end
end

function Feint.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Attacking", false)
end

return Feint