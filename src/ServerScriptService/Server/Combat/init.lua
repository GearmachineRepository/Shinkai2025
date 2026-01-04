--!strict
--[[
	Combat Framework

	A modular, extensible combat system designed to integrate with Ensemble.

	USAGE:
	```lua
	local Combat = require(Server.Combat)

	Combat.Init({
		ActionsFolder = Server.Combat.Actions,
	})
	```

	KEY CONCEPTS:

	1. INPUT RESOLUTION
	   Raw inputs (M1, M2, Block, etc.) are mapped to resolved actions
	   based on the entity's current state. This allows the same input
	   to perform different actions in different contexts.

	   Example: M2 while idle = HeavyAttack, M2 while attacking = Feint

	2. ACTION LIFECYCLE
	   Each action follows a consistent lifecycle:
	   BuildMetadata → CanExecute → OnStart → OnExecute → OnHit → OnComplete/OnInterrupt → OnCleanup

	3. COMBAT EVENTS
	   Granular events are published throughout combat for hooks/passives:
	   - AttackStarted, AttackHit, AttackBlocked, AttackParried
	   - FeintExecuted, CounterHit, ParrySuccess, etc.

	4. STATE-BASED VALIDATION
	   The InputResolver checks entity states to determine which actions
	   are available. Actions also perform their own validation in CanExecute.

	5. WINDOW SYSTEM
	   Actions can open timed windows (PerfectGuard, Counter) that trigger
	   special behavior when hit. Managed centrally by ActionExecutor.

	6. THREAD MANAGEMENT
	   Use ActionExecutor.ScheduleThread() for delayed callbacks that
	   automatically clean up when actions are interrupted.

	EXTENDING THE FRAMEWORK:

	1. Add new actions by creating modules in the Actions folder
	2. Add new input bindings via InputResolver.AddBinding()
	3. Subscribe to combat events for passive/hook effects
	4. Use AttackBase for shared attack logic
	5. Register new windows via ActionExecutor.RegisterWindow()
]]

local ActionRegistry = require(script.Core.ActionRegistry)
local ActionExecutor = require(script.Core.ActionExecutor)
local InputResolver = require(script.Core.InputResolver)
local AttackBase = require(script.Core.AttackBase)
local CombatTypes = require(script.CombatTypes)
local CombatEvents = require(script.CombatEvents)

local PerfectGuard = require(script.Actions.PerfectGuard)
local Counter = require(script.Actions.Counter)

local AnimationTimingCache = require(script.Utility.AnimationTimingCache)

export type Entity = CombatTypes.Entity
export type ActionContext = CombatTypes.ActionContext
export type ActionMetadata = CombatTypes.ActionMetadata
export type ActionDefinition = CombatTypes.ActionDefinition
export type WindowDefinition = CombatTypes.WindowDefinition
export type InputBinding = InputResolver.InputBinding

local Combat = {}

Combat.ActionRegistry = ActionRegistry
Combat.ActionExecutor = ActionExecutor
Combat.InputResolver = InputResolver
Combat.AttackBase = AttackBase
Combat.CombatTypes = CombatTypes
Combat.CombatEvents = CombatEvents

export type InitConfig = {
	ActionsFolder: Instance?,
	AnimationDatabase: {[string]: any}?,
	CustomBindings: { InputResolver.InputBinding }?,
}

function Combat.Init(Config: InitConfig?)
	PerfectGuard.Register()
	Counter.Register()

	local FinalConfig = Config or {} :: InitConfig

	if FinalConfig.ActionsFolder then
		local LoadedCount = ActionRegistry.LoadFolder(FinalConfig.ActionsFolder)
		print("[Combat] Loaded " .. LoadedCount .. " actions")
	end

	if FinalConfig.CustomBindings then
		for _, Binding in FinalConfig.CustomBindings do
			InputResolver.AddBinding(Binding)
		end
	end

	if FinalConfig.AnimationDatabase then
		AnimationTimingCache.PreloadDatabase(FinalConfig.AnimationDatabase)
	end

	print("[Combat] Framework initialized")
	print("[Combat] Registered actions: " .. table.concat(ActionRegistry.GetAllNames(), ", "))
end

function Combat.Execute(Entity: Entity, RawInput: string, InputData: { [string]: any }?): (boolean, string?)
	local ResolvedAction = InputResolver.Resolve(Entity, RawInput)
	if not ResolvedAction then
		return false, "NoValidAction"
	end

	return ActionExecutor.Execute(Entity, ResolvedAction, RawInput, InputData)
end

function Combat.Interrupt(Entity: Entity, Reason: string?): boolean
	return ActionExecutor.Interrupt(Entity, Reason)
end

function Combat.IsExecuting(Entity: Entity): boolean
	return ActionExecutor.IsExecuting(Entity)
end

function Combat.GetActiveAction(Entity: Entity): string?
	return ActionExecutor.GetActiveActionName(Entity)
end

function Combat.GetActiveContext(Entity: Entity): ActionContext?
	return ActionExecutor.GetActiveContext(Entity)
end

function Combat.RegisterAction(Definition: ActionDefinition)
	ActionRegistry.Register(Definition)
end

function Combat.RegisterWindow(Definition: WindowDefinition)
	ActionExecutor.RegisterWindow(Definition)
end

function Combat.OpenWindow(Entity: Entity, WindowType: string, InputTimestamp: number?): boolean
	return ActionExecutor.OpenWindow(Entity, WindowType, InputTimestamp)
end

function Combat.AddInputBinding(Binding: InputResolver.InputBinding, ConfigName: string?)
	InputResolver.AddBinding(Binding, ConfigName)
end

function Combat.RemoveInputBinding(ActionName: string, ConfigName: string?)
	InputResolver.RemoveBinding(ActionName, ConfigName)
end

function Combat.ResolveInput(Entity: Entity, RawInput: string, ConfigName: string?): string?
	return InputResolver.Resolve(Entity, RawInput, ConfigName)
end

function Combat.CleanupEntity(Entity: Entity)
	ActionExecutor.CleanupEntity(Entity)
end

return Combat