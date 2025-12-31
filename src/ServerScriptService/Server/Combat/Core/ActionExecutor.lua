--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionRegistry = require(script.Parent.ActionRegistry)
local AngleValidator = require(script.Parent.Parent.Utility.AngleValidator)
local Packets = require(Shared.Networking.Packets)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionDefinition = CombatTypes.ActionDefinition
type ActionMetadata = CombatTypes.ActionMetadata
type WindowData = CombatTypes.WindowData
type WindowDefinition = CombatTypes.WindowDefinition

local ActionExecutor = {}

local ActiveContexts: { [Entity]: ActionContext } = {}
local ParallelContexts: { [any]: ActionContext } = {}

local EntityComboCounts: { [Entity]: { [string]: number } } = {}
local EntityComboTimers: { [Entity]: { [string]: number } } = {}
local EntityCooldowns: { [Entity]: { [string]: number } } = {}
local RegisteredWindows: { [string]: WindowDefinition } = {}

local DEFAULT_COMBO_RESET_TIME = 2.0

local function PublishEvent(EventName: string, Data: { [string]: any })
	Ensemble.Events.Publish(EventName, Data)
end

local function NotifyCooldown(Entity: Entity, CooldownId: string, Duration: number)
	if not Entity.Player then
		return
	end

	local StartTime = workspace:GetServerTimeNow()
	Packets.StartCooldown:FireClient(Entity.Player, CooldownId, StartTime, Duration)
end

function ActionExecutor.ScheduleThread(Context: ActionContext, Duration: number, Callback: () -> (), IgnoreInterrupt: boolean?): thread
	Context.PendingThreads = Context.PendingThreads or {}

	local NewThread = task.delay(Duration, function()
		if Context.PendingThreads then
			local ThreadList = Context.PendingThreads
			for Index, StoredThread in ThreadList do
				if StoredThread == coroutine.running() then
					table.remove(ThreadList, Index)
					break
				end
			end
		end

		if not IgnoreInterrupt and Context.Interrupted then
			return
		end

		Callback()
	end)

	table.insert(Context.PendingThreads :: { thread }, NewThread)
	return NewThread
end

function ActionExecutor.CancelAllThreads(Context: ActionContext)
	if not Context.PendingThreads then
		return
	end

	for _, Thread in Context.PendingThreads do
		local Status = coroutine.status(Thread)
		if Status == "suspended" then
			task.cancel(Thread)
		end
	end

	table.clear(Context.PendingThreads)
end

function ActionExecutor.RegisterWindow(Definition: WindowDefinition)
	if not Definition.WindowType then
		warn("[ActionExecutor] Cannot register window without WindowType")
		return
	end

	RegisteredWindows[Definition.WindowType] = Definition
end

function ActionExecutor.OpenWindow(Entity: Entity, WindowType: string): boolean
	local Context = ActiveContexts[Entity]
	if not Context then
		return false
	end

	if Context.ActiveWindow then
		return false
	end

	local Definition = RegisteredWindows[WindowType]
	if not Definition then
		warn("[ActionExecutor] Unknown window type: " .. WindowType)
		return false
	end

	if ActionExecutor.IsOnCooldown(Entity, WindowType, Definition.Cooldown) then
		return false
	end

	local FailureCooldownId = WindowType .. "Failure"
	if ActionExecutor.IsOnCooldown(Entity, FailureCooldownId, Definition.SpamCooldown) then
		return false
	end

	local WindowData: WindowData = {
		WindowType = WindowType,
		StartTime = workspace:GetServerTimeNow(),
		Duration = Definition.Duration,
		ExpiryThread = nil,
	}

	Context.ActiveWindow = WindowData
	Entity.States:SetState(Definition.StateName, true)

	PublishEvent(CombatEvents.WindowOpened, {
		Entity = Entity,
		WindowType = WindowType,
		Duration = Definition.Duration,
		Context = Context,
	})

	local ExpiryThread = ActionExecutor.ScheduleThread(Context, Definition.Duration, function()
		if ActionExecutor.IsOnCooldown(Entity, WindowType, Definition.Cooldown) then
			return
		end

		local CurrentContext = ActiveContexts[Entity]
		if CurrentContext ~= Context then
			return
		end

		if not Context.ActiveWindow or Context.ActiveWindow.WindowType ~= WindowType then
			return
		end

		Context.ActiveWindow = nil
		Entity.States:SetState(Definition.StateName, false)

		ActionExecutor.StartCooldown(Entity, FailureCooldownId, Definition.SpamCooldown)

		if Definition.OnExpire then
			Definition.OnExpire(Context)
		end

		PublishEvent(CombatEvents.WindowClosed, {
			Entity = Entity,
			WindowType = WindowType,
			DidTrigger = false,
			Context = Context,
		})
	end, true)

	WindowData.ExpiryThread = ExpiryThread

	return true
end

function ActionExecutor.TriggerWindow(Context: ActionContext, Attacker: Entity): boolean
	if not Context.ActiveWindow then
		return false
	end

	local WindowType = Context.ActiveWindow.WindowType
	local Definition = RegisteredWindows[WindowType]

	if not Definition then
		return false
	end

	if Definition.MaxAngle then
		local HalfAngle = Definition.MaxAngle / 2
		local DefenderCharacter = Context.Entity.Character
		local AttackerCharacter = Attacker.Character

		if DefenderCharacter and AttackerCharacter then
			if not AngleValidator.IsWithinAngle(DefenderCharacter, AttackerCharacter, HalfAngle) then
				return false
			end
		end
	end

	if Context.ActiveWindow.ExpiryThread then
		local Status = coroutine.status(Context.ActiveWindow.ExpiryThread)
		if Status == "suspended" then
			task.cancel(Context.ActiveWindow.ExpiryThread)
		end
	end

	Context.ActiveWindow = nil
	Context.Entity.States:SetState(Definition.StateName, false)

	ActionExecutor.StartCooldown(Context.Entity, WindowType, Definition.Cooldown)

	Definition.OnTrigger(Context, Attacker)

	PublishEvent(CombatEvents.WindowTriggered, {
		Entity = Context.Entity,
		WindowType = WindowType,
		Attacker = Attacker,
		Context = Context,
	})

	return true
end

function ActionExecutor.CloseWindow(Context: ActionContext)
	if not Context.ActiveWindow then
		return
	end

	local WindowType = Context.ActiveWindow.WindowType
	local Definition = RegisteredWindows[WindowType]

	if Context.ActiveWindow.ExpiryThread then
		local Status = coroutine.status(Context.ActiveWindow.ExpiryThread)
		if Status == "suspended" then
			task.cancel(Context.ActiveWindow.ExpiryThread)
		end
	end

	Context.ActiveWindow = nil

	if Definition then
		Context.Entity.States:SetState(Definition.StateName, false)
	end
end

function ActionExecutor.HasActiveWindow(Context: ActionContext): boolean
	return Context.ActiveWindow ~= nil
end

function ActionExecutor.GetActiveWindowType(Context: ActionContext): string?
	if Context.ActiveWindow then
		return Context.ActiveWindow.WindowType
	end
	return nil
end

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

	ActionExecutor.CloseWindow(Context)

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

	ActionExecutor.CloseWindow(Context)
	ActionExecutor.CancelAllThreads(Context)

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

function ActionExecutor.StartCooldown(Entity: Entity, CooldownId: string, Duration: number)
	if Duration <= 0 then
		return
	end

	EntityCooldowns[Entity] = EntityCooldowns[Entity] or {}
	EntityCooldowns[Entity][CooldownId] = workspace:GetServerTimeNow()

	NotifyCooldown(Entity, CooldownId, Duration)
end

function ActionExecutor.ClearCooldown(Entity: Entity, CooldownId: string)
	local Cooldowns = EntityCooldowns[Entity]
	if Cooldowns then
		Cooldowns[CooldownId] = nil
	end

	if Entity.Player then
		Packets.ClearCooldown:FireClient(Entity.Player, CooldownId)
	end
end

function ActionExecutor.IsOnCooldown(Entity: Entity, CooldownId: string, Duration: number): boolean
	local Cooldowns = EntityCooldowns[Entity]
	if not Cooldowns then
		return false
	end

	local LastTime = Cooldowns[CooldownId]
	if not LastTime then
		return false
	end

	return (workspace:GetServerTimeNow() - LastTime) < Duration
end

function ActionExecutor.GetComboCount(Entity: Entity, ActionName: string): number
	local Counts = EntityComboCounts[Entity]
	if not Counts then
		return 1
	end

	return Counts[ActionName] or 1
end

function ActionExecutor.AdvanceCombo(Entity: Entity, ActionName: string, CurrentIndex: number, MaxIndex: number)
	EntityComboCounts[Entity] = EntityComboCounts[Entity] or {}
	EntityComboTimers[Entity] = EntityComboTimers[Entity] or {}

	local NextIndex = if CurrentIndex >= MaxIndex then 1 else CurrentIndex + 1
	EntityComboCounts[Entity][ActionName] = NextIndex
	EntityComboTimers[Entity][ActionName] = workspace:GetServerTimeNow()

	if Entity.Character then
		Entity.Character:SetAttribute(ActionName .. "ComboCount", NextIndex)
	end

	PublishEvent(CombatEvents.ComboAdvanced, {
		Entity = Entity,
		ActionName = ActionName,
		PreviousIndex = CurrentIndex,
		NewIndex = NextIndex,
		MaxIndex = MaxIndex,
	})

	local ResetTime = DEFAULT_COMBO_RESET_TIME

	task.delay(ResetTime, function()
		local Timers = EntityComboTimers[Entity]
		if not Timers then
			return
		end

		local LastTime = Timers[ActionName]
		if not LastTime then
			return
		end

		if (workspace:GetServerTimeNow() - LastTime) >= ResetTime then
			local Counts = EntityComboCounts[Entity]
			if Counts then
				Counts[ActionName] = 1
			end

			if Entity.Character then
				Entity.Character:SetAttribute(ActionName .. "ComboCount", 1)
			end

			PublishEvent(CombatEvents.ComboReset, {
				Entity = Entity,
				ActionName = ActionName,
			})
		end
	end)
end

function ActionExecutor.ResetCombo(Entity: Entity, ActionName: string)
	local Counts = EntityComboCounts[Entity]
	if Counts then
		Counts[ActionName] = 1
	end

	if Entity.Character then
		Entity.Character:SetAttribute(ActionName .. "ComboCount", 1)
	end
end

-----------------[[Parallel action support]]------------------------------

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

    ActionExecutor.CancelAllThreads(Context)

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
	ActiveContexts[Entity] = nil
	EntityComboCounts[Entity] = nil
	EntityComboTimers[Entity] = nil
	EntityCooldowns[Entity] = nil
end

return ActionExecutor