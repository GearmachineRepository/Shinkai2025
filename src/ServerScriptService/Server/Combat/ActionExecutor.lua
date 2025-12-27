--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.CombatTypes)
local ActionRegistry = require(script.Parent.ActionRegistry)
local AnimationTimingCache = require(script.Parent.AnimationTimingCache)

type ActionContext = CombatTypes.ActionContext
type ActionDefinition = CombatTypes.ActionDefinition
type ActionMetadata = CombatTypes.ActionMetadata

local ActionExecutor = {}

local ActiveContexts: { [any]: ActionContext } = {}

-- Creates and initializes a new ActionContext with standard defaults for runtime execution tracking.
local function CreateContext(Entity: CombatTypes.Entity, Metadata: ActionMetadata, InputData: any?): ActionContext
	return {
		Entity = Entity,
		InputData = InputData or {},
		Metadata = Metadata,
		StartTime = workspace:GetServerTimeNow(),
		Interrupted = false,
		InterruptReason = nil,
		CustomData = {},
	}
end

-- Executes an action by name for an entity, running validation hooks, publishing lifecycle events, and starting async execution.
function ActionExecutor.Execute(
	Entity: CombatTypes.Entity,
	ActionName: string,
	InputData: { [string]: any }?
): (boolean, string?)

    if ActiveContexts[Entity] ~= nil then
        return false, "Already executing"
    end

	local Definition: ActionDefinition?, Metadata: ActionMetadata? = ActionRegistry.GetWithMetadata(ActionName, nil)

	if not Definition or not Metadata then
		return false, "Unknown action"
	end

	local Context = CreateContext(Entity, Metadata, InputData)

	if Definition.CanExecute then
		local CanExecute: boolean, Reason: string? = Definition.CanExecute(Context)
		if not CanExecute then
			return false, Reason or "Cannot execute"
		end
	end

	local ModifiedMetadata: ActionMetadata = table.clone(Metadata)

	Ensemble.Events.Publish("ActionConfiguring", {
		Entity = Entity,
		ActionName = ActionName,
		Metadata = ModifiedMetadata,
	})

	Context.Metadata = ModifiedMetadata
	ActiveContexts[Entity] = Context

	if Definition.OnStart then
		Definition.OnStart(Context)
	end

	Ensemble.Events.Publish("ActionStarted", {
		Entity = Entity,
		ActionName = ActionName,
		Metadata = ModifiedMetadata,
		Context = Context,
	})

	task.spawn(function()
		Definition.OnExecute(Context)

		if not Context.Interrupted then
			ActionExecutor.Complete(Entity)
		end
	end)

	return true, nil
end

-- Interrupts the currently executing action for an entity, invokes interrupt hooks, publishes an event, and performs cleanup.
function ActionExecutor.Interrupt(Entity: CombatTypes.Entity, Reason: string?): boolean
	local Context = ActiveContexts[Entity]
	if not Context then
		return false
	end

	if Context.Interrupted then
		return false
	end

	if not Context.Metadata then
		return false
	end

	local InterruptReason = Reason or "Unknown"

	if InterruptReason == "Feint" then
		if not Context.CustomData.CanFeint or not Context.Metadata.Feintable then
			return false
		end
	end

	Context.Interrupted = true
	Context.InterruptReason = InterruptReason

	local Definition: ActionDefinition? = ActionRegistry.Get(Context.Metadata.ActionName)

	if Definition and Definition.OnInterrupt then
		Definition.OnInterrupt(Context)
	end

	Ensemble.Events.Publish("ActionInterrupted", {
		Entity = Entity,
		ActionName = Context.Metadata.ActionName,
		Reason = InterruptReason,
		Context = Context,
	})

	ActionExecutor.Cleanup(Entity)

	return true
end

-- Completes the currently executing action for an entity if it was not interrupted, invokes completion hooks, publishes an event, and performs cleanup.
function ActionExecutor.Complete(Entity: CombatTypes.Entity)
	local Context = ActiveContexts[Entity]
	if not Context then
		return
	end

	if Context.Interrupted then
		return
	end

	if not Context.Metadata then
		return
	end

	local Definition: ActionDefinition? = ActionRegistry.Get(Context.Metadata.ActionName)

	if Definition and Definition.OnComplete then
		Definition.OnComplete(Context)
	end

	Ensemble.Events.Publish("ActionCompleted", {
		Entity = Entity,
		ActionName = Context.Metadata.ActionName,
		Context = Context,
	})

	ActionExecutor.Cleanup(Entity)
end

-- Performs final teardown for an entity's active action, invoking cleanup hooks and removing the active context.
function ActionExecutor.Cleanup(Entity: CombatTypes.Entity)
	local Context = ActiveContexts[Entity]
	if not Context then
		return
	end

	if not Context.Metadata then
		return
	end

	local Definition: ActionDefinition? = ActionRegistry.Get(Context.Metadata.ActionName)

	if Definition and Definition.OnCleanup then
		Definition.OnCleanup(Context)
	end

	ActiveContexts[Entity] = nil
end

-- Returns the current active ActionContext for an entity, if any.
function ActionExecutor.GetActiveContext(Entity: CombatTypes.Entity): ActionContext?
	return ActiveContexts[Entity]
end

-- Returns whether an entity currently has an active executing action context.
function ActionExecutor.IsExecuting(Entity: CombatTypes.Entity): boolean
	return ActiveContexts[Entity] ~= nil
end

-- Retrieves animation marker timings from cache and merges in fallback defaults for any missing markers.
function ActionExecutor.GetTimings(AnimationId: string, Fallbacks: { [string]: number }?): { [string]: number }
	local Timings: { [string]: number } = {}
	local Defaults: { [string]: number } = Fallbacks or {}

	local Cached = AnimationTimingCache.GetAllMarkers(AnimationId)

	if Cached then
		for MarkerName, MarkerData in Cached do
			Timings[MarkerName] = MarkerData.Time
		end
	end

	for Key, Value in pairs(Defaults) do
		if Timings[Key] == nil then
			Timings[Key] = Value
		end
	end

	return Timings
end

return ActionExecutor