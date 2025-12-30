--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)

local DashBalance = require(Shared.Configurations.Balance.DashBalance)
local ActionValidator = require(Shared.Utils.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local DodgeCancel = {}

DodgeCancel.ActionName = "DodgeCancel"
DodgeCancel.ActionType = "Utility"
DodgeCancel.RequiresActiveAction = true

local COOLDOWN_ID = "DodgeCancel"
local DEFAULT_COOLDOWN = DashBalance.DodgeCancelCooldown or 1.0
local DEFAULT_ENDLAG = DashBalance.DodgeCancelEndlag or 0.15

function DodgeCancel.BuildMetadata(Entity: Entity, _InputData: { [string]: any }?): ActionMetadata?
	local ActiveContext = ActionExecutor.GetActiveContext(Entity)
	if not ActiveContext then
		return nil
	end

	if ActiveContext.Metadata.ActionName ~= "Dodge" then
		return nil
	end

	local Metadata: ActionMetadata = {
		ActionName = "DodgeCancel",
		ActionType = "Utility",
		DodgeCancelCooldown = DEFAULT_COOLDOWN,
		DodgeCancelEndlag = DEFAULT_ENDLAG,
	}

	return Metadata
end

function DodgeCancel.CanExecute(Context: ActionContext): (boolean, string?)
	local Entity = Context.Entity
	local InterruptedContext = Context.InterruptedContext

	local CanPerform, Reason = ActionValidator.CanPerform(Entity.States, "DodgeCancel")
	if not CanPerform then
		return false, Reason
	end

	if not InterruptedContext then
		return false, "NoActiveAction"
	end

	if InterruptedContext.Metadata.ActionName ~= "Dodge" then
		return false, "NotDodging"
	end

	local CancelCooldown = Context.Metadata.DodgeCancelCooldown or DEFAULT_COOLDOWN
	if ActionExecutor.IsOnCooldown(Entity, COOLDOWN_ID, CancelCooldown) then
		return false, "OnCooldown"
	end

	return true, nil
end

function DodgeCancel.OnStart(Context: ActionContext)
	local CancelCooldown = Context.Metadata.DodgeCancelCooldown or DEFAULT_COOLDOWN
	ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, CancelCooldown)
end

function DodgeCancel.OnExecute(Context: ActionContext)
	local InterruptedContext = Context.InterruptedContext
	local SourceAction = InterruptedContext and InterruptedContext.Metadata.ActionName or "Unknown"

	Ensemble.Events.Publish(CombatEvents.DodgeCancelExecuted, {
		Entity = Context.Entity,
		SourceAction = SourceAction,
		Context = Context,
	})

	local CancelEndlag = Context.Metadata.DodgeCancelEndlag or DEFAULT_ENDLAG
	if CancelEndlag > 0 then
		task.wait(CancelEndlag)
	end
end

function DodgeCancel.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Dodging", false)
	Context.Entity.States:SetState("Invulnerable", false)
end

return DodgeCancel