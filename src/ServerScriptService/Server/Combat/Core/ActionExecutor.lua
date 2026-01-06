--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionRegistry = require(script.Parent.ActionRegistry)

local ComboTracker = require(script.Parent.ComboTracker)
local CooldownManager = require(script.Parent.CooldownManager)
local WindowManager = require(script.Parent.WindowManager)
local ThreadScheduler = require(script.Parent.ThreadScheduler)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionDefinition = CombatTypes.ActionDefinition
type ActionMetadata = CombatTypes.ActionMetadata
type WindowDefinition = CombatTypes.WindowDefinition

local ActionExecutor = {}

local ActiveContexts: { [Entity]: ActionContext } = {}
local ParallelContexts: { [Entity]: ActionContext } = {}

local function PublishEvent(EventName: string, Data: { [string]: any })
	Ensemble.Events.Publish(EventName, Data)
end

ComboTracker.SetEventPublisher(PublishEvent)
WindowManager.SetEventPublisher(PublishEvent)

function ActionExecutor.Execute(
	Entity: Entity,
	ActionName: string,
	RawInput: string?,
	InputData: { [string]: any }?
): (boolean, string?)
	local Definition = ActionRegistry.Get(ActionName)
	if not Definition then
		return false, "UnknownAction"
	end

	local ActiveContext = ActiveContexts[Entity]

	if Definition.RequiresActiveAction then
		if not ActiveContext then
			return false, "NoActiveAction"
		end
	else
		if ActiveContext then
			return false, "AlreadyExecuting"
		end
	end

	local FinalInputData = InputData or {}
	local Metadata: ActionMetadata

	if Definition.BuildMetadata then
		local BuiltMetadata = Definition.BuildMetadata(Entity, FinalInputData)
		if not BuiltMetadata then
			return false, "FailedToBuildMetadata"
		end
		Metadata = BuiltMetadata
	elseif Definition.DefaultMetadata then
		Metadata = table.clone(Definition.DefaultMetadata)
	else
		Metadata = {
			ActionName = ActionName,
			ActionType = Definition.ActionType,
		}
	end

	local Context: ActionContext = {
		Entity = Entity,
		RawInput = RawInput,
		InputData = FinalInputData,
		Metadata = Metadata,
		StartTime = workspace:GetServerTimeNow(),
		Interrupted = false,
		InterruptReason = nil,
		InterruptedContext = ActiveContext,
		CustomData = {},
		ActiveWindow = nil,
		PendingThreads = {},
	}

	PublishEvent(CombatEvents.ActionConfiguring, {
		Entity = Entity,
		ActionName = ActionName,
		Context = Context,
	})

	if Definition.CanExecute then
		local CanExecute, Reason = Definition.CanExecute(Context)
		if not CanExecute then
			return false, Reason or "CannotExecute"
		end
	end

	if Definition.RequiresActiveAction and ActiveContext then
		ActiveContext.Interrupted = true
		ActiveContext.InterruptReason = ActionName

		local ActiveDefinition = ActionRegistry.Get(ActiveContext.Metadata.ActionName)
		if ActiveDefinition and ActiveDefinition.OnInterrupt then
			ActiveDefinition.OnInterrupt(ActiveContext)
		end

		PublishEvent(CombatEvents.ActionInterrupted, {
			Entity = Entity,
			ActionName = ActiveContext.Metadata.ActionName,
			Reason = ActionName,
			Context = ActiveContext,
		})

		if ActiveDefinition and ActiveDefinition.OnCleanup then
			ActiveDefinition.OnCleanup(ActiveContext)
		end
	end

	ActiveContexts[Entity] = Context

	if Definition.OnStart then
		Definition.OnStart(Context)
	end

	PublishEvent(CombatEvents.ActionStarted, {
		Entity = Entity,
		ActionName = ActionName,
		ActionType = Definition.ActionType,
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

function ActionExecutor.Interrupt(Entity: Entity, Reason: string?): boolean
	local Context = ActiveContexts[Entity]
	if not Context or Context.Interrupted then
		return false
	end

	local InterruptReason = Reason or "Unknown"

	Context.Interrupted = true
	Context.InterruptReason = InterruptReason

	WindowManager.Close(Context)

	local ActionName = Context.Metadata.ActionName
	local Definition = ActionRegistry.Get(ActionName)

	if Definition and Definition.OnInterrupt then
		Definition.OnInterrupt(Context)
	end

	PublishEvent(CombatEvents.ActionInterrupted, {
		Entity = Entity,
		ActionName = ActionName,
		Reason = InterruptReason,
		Context = Context,
	})

	ActionExecutor.Cleanup(Entity)
	return true
end

function ActionExecutor.Complete(Entity: Entity)
	local Context = ActiveContexts[Entity]
	if not Context or Context.Interrupted then
		return
	end

	local ActionName = Context.Metadata.ActionName
	local Definition = ActionRegistry.Get(ActionName)

	if Definition and Definition.OnComplete then
		Definition.OnComplete(Context)
	end

	PublishEvent(CombatEvents.ActionCompleted, {
		Entity = Entity,
		ActionName = ActionName,
		Context = Context,
	})

	ActionExecutor.Cleanup(Entity)
end

function ActionExecutor.Cleanup(Entity: Entity)
	local Context = ActiveContexts[Entity]
	if not Context then
		return
	end

	WindowManager.Close(Context)
	ThreadScheduler.CancelAll(Context)

	local ActionName = Context.Metadata.ActionName
	local Definition = ActionRegistry.Get(ActionName)

	if Definition and Definition.OnCleanup then
		Definition.OnCleanup(Context)
	end

	Entity.States:SetState("Attacking", false)
	ActiveContexts[Entity] = nil
end

function ActionExecutor.GetActiveContext(Entity: Entity): ActionContext?
	return ActiveContexts[Entity]
end

function ActionExecutor.IsExecuting(Entity: Entity): boolean
	return ActiveContexts[Entity] ~= nil
end

function ActionExecutor.GetActiveActionName(Entity: Entity): string?
	local Context = ActiveContexts[Entity]
	if Context then
		return Context.Metadata.ActionName
	end
	return nil
end

function ActionExecutor.ScheduleThread(Context: ActionContext, Duration: number, Callback: () -> (), IgnoreInterrupt: boolean?): thread
	return ThreadScheduler.Schedule(Context, Duration, Callback, IgnoreInterrupt)
end

function ActionExecutor.CancelAllThreads(Context: ActionContext)
	ThreadScheduler.CancelAll(Context)
end

function ActionExecutor.RegisterWindow(Definition: WindowDefinition)
	WindowManager.Register(Definition)
end

function ActionExecutor.OpenWindow(Entity: Entity, WindowType: string, InputTimestamp: number?): boolean
	local Context = ActiveContexts[Entity]
	if not Context then
		return false
	end

	return WindowManager.Open(Context, WindowType, InputTimestamp)
end

function ActionExecutor.TriggerWindow(Context: ActionContext, Attacker: Entity): boolean
	return WindowManager.Trigger(Context, Attacker)
end

function ActionExecutor.CloseWindow(Context: ActionContext)
	WindowManager.Close(Context)
end

function ActionExecutor.HasActiveWindow(Context: ActionContext): boolean
	return WindowManager.HasActiveWindow(Context)
end

function ActionExecutor.GetActiveWindowType(Context: ActionContext): string?
	return WindowManager.GetActiveWindowType(Context)
end

function ActionExecutor.StartCooldown(Entity: Entity, CooldownId: string, Duration: number)
	CooldownManager.Start(Entity, CooldownId, Duration)
end

function ActionExecutor.ClearCooldown(Entity: Entity, CooldownId: string)
	CooldownManager.Clear(Entity, CooldownId)
end

function ActionExecutor.IsOnCooldown(Entity: Entity, CooldownId: string, Duration: number): boolean
	return CooldownManager.IsOnCooldown(Entity, CooldownId, Duration)
end

function ActionExecutor.GetComboCount(Entity: Entity, ActionName: string): number
	return ComboTracker.GetCount(Entity, ActionName)
end

function ActionExecutor.AdvanceCombo(Entity: Entity, ActionName: string, CurrentIndex: number, MaxIndex: number)
	local ResetTime = nil
	local Context = ActiveContexts[Entity]
	if Context and Context.Metadata.ComboResetTime then
		ResetTime = Context.Metadata.ComboResetTime
	end

	ComboTracker.Advance(Entity, ActionName, CurrentIndex, MaxIndex, ResetTime)
end

function ActionExecutor.ResetCombo(Entity: Entity, ActionName: string)
	ComboTracker.Reset(Entity, ActionName)
end

function ActionExecutor.ExecuteParallel(
	Entity: Entity,
	ActionName: string,
	RawInput: string?,
	InputData: { [string]: any }?
): (boolean, string?)
	local Definition = ActionRegistry.Get(ActionName)
	if not Definition then
		return false, "UnknownAction"
	end

	if ParallelContexts[Entity] then
		return false, "ParallelActionActive"
	end

	local FinalInputData = InputData or {}
	local Metadata: ActionMetadata

	if Definition.BuildMetadata then
		local BuiltMetadata = Definition.BuildMetadata(Entity, FinalInputData)
		if not BuiltMetadata then
			return false, "FailedToBuildMetadata"
		end
		Metadata = BuiltMetadata
	elseif Definition.DefaultMetadata then
		Metadata = table.clone(Definition.DefaultMetadata)
	else
		Metadata = {
			ActionName = ActionName,
			ActionType = Definition.ActionType,
		}
	end

	local Context: ActionContext = {
		Entity = Entity,
		RawInput = RawInput,
		InputData = FinalInputData,
		Metadata = Metadata,
		StartTime = workspace:GetServerTimeNow(),
		Interrupted = false,
		InterruptReason = nil,
		InterruptedContext = nil,
		CustomData = {},
		ActiveWindow = nil,
		PendingThreads = {},
	}

	if Definition.CanExecute then
		local CanExecute, Reason = Definition.CanExecute(Context)
		if not CanExecute then
			return false, Reason or "CannotExecute"
		end
	end

	ParallelContexts[Entity] = Context

	if Definition.OnStart then
		Definition.OnStart(Context)
	end

	PublishEvent(CombatEvents.ActionStarted, {
		Entity = Entity,
		ActionName = ActionName,
		ActionType = Definition.ActionType,
		Context = Context,
		IsParallel = true,
	})

	task.spawn(function()
		Definition.OnExecute(Context)

		if not Context.Interrupted then
			ActionExecutor.CompleteParallel(Entity)
		end
	end)

	return true, nil
end

function ActionExecutor.CompleteParallel(Entity: Entity)
	local Context = ParallelContexts[Entity]
	if not Context or Context.Interrupted then
		return
	end

	local ActionName = Context.Metadata.ActionName
	local Definition = ActionRegistry.Get(ActionName)

	if Definition and Definition.OnComplete then
		Definition.OnComplete(Context)
	end

	PublishEvent(CombatEvents.ActionCompleted, {
		Entity = Entity,
		ActionName = ActionName,
		Context = Context,
		IsParallel = true,
	})

	ActionExecutor.CleanupParallel(Entity)
end

function ActionExecutor.InterruptParallel(Entity: Entity, Reason: string?): boolean
	local Context = ParallelContexts[Entity]
	if not Context or Context.Interrupted then
		return false
	end

	Context.Interrupted = true
	Context.InterruptReason = Reason or "Unknown"

	local ActionName = Context.Metadata.ActionName
	local Definition = ActionRegistry.Get(ActionName)

	if Definition and Definition.OnInterrupt then
		Definition.OnInterrupt(Context)
	end

	PublishEvent(CombatEvents.ActionInterrupted, {
		Entity = Entity,
		ActionName = ActionName,
		Reason = Reason,
		Context = Context,
		IsParallel = true,
	})

	ActionExecutor.CleanupParallel(Entity)
	return true
end

function ActionExecutor.CleanupParallel(Entity: Entity)
	local Context = ParallelContexts[Entity]
	if not Context then
		return
	end

	ThreadScheduler.CancelAll(Context)

	local ActionName = Context.Metadata.ActionName
	local Definition = ActionRegistry.Get(ActionName)

	if Definition and Definition.OnCleanup then
		Definition.OnCleanup(Context)
	end

	ParallelContexts[Entity] = nil
end

function ActionExecutor.GetParallelContext(Entity: Entity): ActionContext?
	return ParallelContexts[Entity]
end

function ActionExecutor.IsParallelExecuting(Entity: Entity): boolean
	return ParallelContexts[Entity] ~= nil
end

function ActionExecutor.CleanupEntity(Entity: Entity)
	local Context = ActiveContexts[Entity]
	if Context then
		ThreadScheduler.CancelAll(Context)
	end

	local ParallelContext = ParallelContexts[Entity]
	if ParallelContext then
		ThreadScheduler.CancelAll(ParallelContext)
	end

	ActiveContexts[Entity] = nil
	ParallelContexts[Entity] = nil

	ComboTracker.CleanupEntity(Entity)
	CooldownManager.CleanupEntity(Entity)
end

ActionExecutor.ComboTracker = ComboTracker
ActionExecutor.CooldownManager = CooldownManager
ActionExecutor.WindowManager = WindowManager
ActionExecutor.ThreadScheduler = ThreadScheduler

return ActionExecutor