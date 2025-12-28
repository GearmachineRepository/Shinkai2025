--!strict

local EnsembleTypes = require(game.ServerScriptService.Server.Ensemble.Types)

export type Entity = EnsembleTypes.Entity

export type ActionMetadata = {
	ActionName: string,
	AnimationSet: string,
	AnimationId: string,
	ComboCount: number,

	Damage: number,
	StaminaCost: number,
	HitStun: number,

	HitboxSize: Vector3,
	HitboxOffset: Vector3,

	Feintable: boolean,
	FeintEndlag: number,
	FeintCooldown: number,
	ComboEndlag: number,
	ComboResetTime: number,
	StaminaCostHitReduction: number,

	FallbackHitStart: number,
	FallbackHitEnd: number,
	FallbackLength: number,
}

export type ActionContext = {
	Entity: Entity,
	InputData: { [string]: any },
	Metadata: ActionMetadata,
	StartTime: number,
	Interrupted: boolean,
	InterruptReason: string?,
	CustomData: { [string]: any },
}

export type ActionDefinition = {
	ActionName: string,
	ActionType: "Attack" | "Ability" | "Defensive" | "Movement",

	CanExecute: ((Context: ActionContext) -> (boolean, string?))?,
	OnStart: ((Context: ActionContext) -> ())?,
	OnExecute: (Context: ActionContext) -> (),
	OnHit: ((Context: ActionContext, Target: Entity, HitIndex: number) -> ())?,
	OnInterrupt: ((Context: ActionContext) -> ())?,
	OnComplete: ((Context: ActionContext) -> ())?,
	OnCleanup: ((Context: ActionContext) -> ())?,
}

export type StateHandler = {
	OnEnter: ((Entity: Entity, EventData: any) -> ())?,
	OnExit: ((Entity: Entity, EventData: any) -> ())?,
	OnUpdate: ((Entity: Entity, DeltaTime: number) -> ())?,
}

export type HitboxConfig = {
	Owner: Entity,
	Size: Vector3,
	Offset: CFrame,
	Duration: number,
	OnHit: (Target: Entity) -> (),
	MaxTargets: number?,
	IgnoreList: { Model }?,
	Shape: "Box" | "Sphere"?,
}

return nil