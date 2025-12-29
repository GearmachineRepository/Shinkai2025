--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.CombatTypes)
local CombatEvents = require(script.Parent.CombatEvents)
local ActionRegistry = require(script.Parent.ActionRegistry)
local Packets = require(Shared.Networking.Packets)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionDefinition = CombatTypes.ActionDefinition
type ActionMetadata = CombatTypes.ActionMetadata

local ActionExecutor = {}

local ActiveContexts: { [Entity]: ActionContext } = {}
local EntityComboCounts: { [Entity]: { [string]: number } } = {}
local EntityComboTimers: { [Entity]: { [string]: number } } = {}
local EntityCooldowns: { [Entity]: { [string]: number } } = {}

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

function ActionExecutor.GetComboCount(Entity: Entity, ActionName: string): number
	local CurrentTime = os.clock()
	local ComboTimers = EntityComboTimers[Entity]
	local ComboCounts = EntityComboCounts[Entity]

	if ComboTimers and ComboTimers[ActionName] then
		local ResetTime = DEFAULT_COMBO_RESET_TIME
		if (CurrentTime - ComboTimers[ActionName]) > ResetTime then
			if ComboCounts then
				ComboCounts[ActionName] = nil
			end
			ComboTimers[ActionName] = nil

			PublishEvent(CombatEvents.ComboReset, {
				Entity = Entity,
				ActionName = ActionName,
			})

			return 1
		end
	end

	if ComboCounts and ComboCounts[ActionName] then
		return ComboCounts[ActionName]
	end

	return 1
end

function ActionExecutor.AdvanceCombo(Entity: Entity, ActionName: string, CurrentIndex: number, MaxLength: number)
	if not EntityComboCounts[Entity] then
		EntityComboCounts[Entity] = {}
	end
	if not EntityComboTimers[Entity] then
		EntityComboTimers[Entity] = {}
	end

	local NewIndex = (CurrentIndex % MaxLength) + 1
	EntityComboCounts[Entity][ActionName] = NewIndex
	EntityComboTimers[Entity][ActionName] = os.clock()

	if Entity.Character then
		Entity.Character:SetAttribute(ActionName .. "ComboCount", NewIndex)
	end

	PublishEvent(CombatEvents.ComboAdvanced, {
		Entity = Entity,
		ActionName = ActionName,
		ComboIndex = NewIndex,
		MaxLength = MaxLength,
	})

	if CurrentIndex == MaxLength then
		PublishEvent(CombatEvents.ComboFinished, {
			Entity = Entity,
			ActionName = ActionName,
		})
	end
end

function ActionExecutor.ResetCombo(Entity: Entity, ActionName: string?)
	if ActionName then
		if EntityComboCounts[Entity] then
			EntityComboCounts[Entity][ActionName] = nil
		end
		if EntityComboTimers[Entity] then
			EntityComboTimers[Entity][ActionName] = nil
		end
		if Entity.Character then
			Entity.Character:SetAttribute(ActionName .. "ComboCount", 1)
		end
	else
		EntityComboCounts[Entity] = nil
		EntityComboTimers[Entity] = nil
	end

	PublishEvent(CombatEvents.ComboReset, {
		Entity = Entity,
		ActionName = ActionName,
	})
end

function ActionExecutor.StartCooldown(Entity: Entity, CooldownId: string, Duration: number)
	if not EntityCooldowns[Entity] then
		EntityCooldowns[Entity] = {}
	end

	EntityCooldowns[Entity][CooldownId] = workspace:GetServerTimeNow()
	NotifyCooldown(Entity, CooldownId, Duration)

	PublishEvent(CombatEvents.CooldownStarted, {
		Entity = Entity,
		CooldownId = CooldownId,
		Duration = Duration,
	})
end

function ActionExecutor.GetCooldownRemaining(Entity: Entity, CooldownId: string, Duration: number): number
	local Cooldowns = EntityCooldowns[Entity]
	if not Cooldowns or not Cooldowns[CooldownId] then
		return 0
	end

	local Elapsed = workspace:GetServerTimeNow() - Cooldowns[CooldownId]
	return math.max(0, Duration - Elapsed)
end

function ActionExecutor.IsOnCooldown(Entity: Entity, CooldownId: string, Duration: number): boolean
	return ActionExecutor.GetCooldownRemaining(Entity, CooldownId, Duration) > 0
end

function ActionExecutor.ClearCooldown(Entity: Entity, CooldownId: string)
	if EntityCooldowns[Entity] then
		EntityCooldowns[Entity][CooldownId] = nil
	end

	if Entity.Player then
		Packets.ClearCooldown:FireClient(Entity.Player, CooldownId)
	end

	PublishEvent(CombatEvents.CooldownEnded, {
		Entity = Entity,
		CooldownId = CooldownId,
	})
end

function ActionExecutor.CleanupEntity(Entity: Entity)
	ActiveContexts[Entity] = nil
	EntityComboCounts[Entity] = nil
	EntityComboTimers[Entity] = nil
	EntityCooldowns[Entity] = nil
end

return ActionExecutor