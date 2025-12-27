--!strict

local Types = {}

Types.EngineName = "Ensemble"

export type CleanupTask = RBXScriptConnection | Instance | (() -> ()) | { Destroy: (any) -> () } | { Disconnect: (any) -> () }

export type Maid = {
	Tasks: { [any]: CleanupTask },
	GiveTask: (self: Maid, Task: CleanupTask) -> CleanupTask,
	Set: (self: Maid, Name: string, Task: CleanupTask?) -> (),
	CleanupItem: (self: Maid, Task: CleanupTask) -> (),
	DoCleaning: (self: Maid) -> (),
}

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, Callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, Callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

export type StateDefinition = {
	Default: boolean?,
	Replication: "All" | "Owner" | "None",
	Conflicts: { string }?,
	LockMovement: boolean?,
}

export type StateConfig = {
	States: { [string]: StateDefinition },
}

export type StatDefinition = {
	Default: number,
	Min: number?,
	Max: number?,
	Replication: "All" | "Owner" | "None",
}

export type StatConfig = {
	Stats: { [string]: StatDefinition },
}

export type EventConfig = {
	Events: { string },
}

export type ArchetypeConfig = {
	[string]: { string },
}

export type EngineConfigs = {
	States: StateConfig,
	Stats: StatConfig,
	Events: EventConfig,
}

export type InitConfig = {
	Components: Instance,
	Hooks: Instance,
	Configs: EngineConfigs,
	Archetypes: ArchetypeConfig?,
}

export type ComponentMetadata = {
	ComponentName: string,
	Dependencies: { string }?,
	UpdateRate: number?,
}

export type ComponentModule = ComponentMetadata & {
	new: (Entity: Entity, Context: EntityContext) -> Component,
}

export type Component = {
	Entity: Entity,
	Update: ((self: Component, DeltaTime: number) -> ())?,
	Destroy: (self: Component) -> (),
}

export type HookDefinition = {
	HookName: string,
	Description: string?,
	OnActivate: (Entity: Entity) -> (() -> ())?,
	OnDeactivate: ((Entity: Entity) -> ())?,
}

export type EntityContext = {
	Player: Player?,
	Data: { [string]: any }?,
	[string]: any,
}

export type ModifierFunction = (BaseValue: number, Data: { [string]: any }?) -> number

export type Modifier = {
	Type: string,
	Priority: number,
	ModifyFunction: ModifierFunction,
}

export type StateComponent = {
	GetState: (self: StateComponent, StateName: string) -> boolean,
	SetState: (self: StateComponent, StateName: string, Value: boolean) -> (),
	OnStateChanged: (self: StateComponent, StateName: string, Callback: (Value: boolean) -> ()) -> Connection,
	Destroy: (self: StateComponent) -> (),
}

export type StatComponent = {
	GetStat: (self: StatComponent, StatName: string) -> number,
	SetStat: (self: StatComponent, StatName: string, Value: number) -> (),
	ModifyStat: (self: StatComponent, StatName: string, Delta: number) -> (),
	GetAllStats: (self: StatComponent) -> { [string]: number },
	OnStatChanged: (self: StatComponent, StatName: string, Callback: (NewValue: number, OldValue: number) -> ()) -> Connection,
	Destroy: (self: StatComponent) -> (),
}

export type ModifierComponent = {
	Register: (self: ModifierComponent, Type: string, Priority: number, ModifyFunction: ModifierFunction) -> () -> (),
	Unregister: (self: ModifierComponent, Type: string, ModifyFunction: ModifierFunction) -> (),
	Apply: (self: ModifierComponent, Type: string, BaseValue: number, Data: { [string]: any }?) -> number,
	GetCount: (self: ModifierComponent, Type: string) -> number,
	Clear: (self: ModifierComponent, Type: string?) -> (),
	Destroy: (self: ModifierComponent) -> (),
}

export type HookComponent = {
	RegisterHook: (self: HookComponent, HookName: string) -> (),
	UnregisterHook: (self: HookComponent, HookName: string) -> (),
	GetActiveHooks: (self: HookComponent) -> { string },
	HasHook: (self: HookComponent, HookName: string) -> boolean,
	Destroy: (self: HookComponent) -> (),
}

export type Entity = {
	Character: Model,
	Humanoid: Humanoid,
	IsPlayer: boolean,
	Player: Player?,
	Context: EntityContext,

	States: StateComponent,
	Stats: StatComponent,
	Modifiers: ModifierComponent,
	Hooks: HookComponent,

	GetComponent: <T>(self: Entity, ComponentName: string) -> T?,
	HasComponent: (self: Entity, ComponentName: string) -> boolean,
	AddComponent: (self: Entity, ComponentName: string, ComponentInstance: any) -> (),
	TakeDamage: (self: Entity, Damage: number, Source: Player?, Direction: Vector3?) -> (),
	DealDamage: (self: Entity, Target: Model, BaseDamage: number) -> (),
	FireCreated: (self: Entity) -> (),
	Destroy: (self: Entity) -> (),
}

export type EntityBuilder = {
	WithComponent: (self: EntityBuilder, ComponentName: string, ...any) -> EntityBuilder,
	WithComponents: (self: EntityBuilder, ...string) -> EntityBuilder,
	WithComponentsFromList: (self: EntityBuilder, ComponentList: { string }) -> EntityBuilder,
	WithArchetype: (self: EntityBuilder, ArchetypeName: string) -> EntityBuilder,
	WithoutComponent: (self: EntityBuilder, ComponentName: string) -> EntityBuilder,
	WithHook: (self: EntityBuilder, HookName: string) -> EntityBuilder,
	WithHooks: (self: EntityBuilder, HookNames: { string }?) -> EntityBuilder,
	Build: (self: EntityBuilder) -> Entity,
}

export type ValidationError = {
	Field: string,
	Message: string,
}

export type ValidationResult = {
	Valid: boolean,
	Errors: { ValidationError },
}

return Types