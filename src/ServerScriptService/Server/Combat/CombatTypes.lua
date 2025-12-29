--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local EnsembleTypes = require(ServerScriptService.Server.Ensemble.Types)

export type Entity = EnsembleTypes.Entity

export type HitboxData = {
	Size: Vector3,
	Offset: Vector3,
}

export type AttackData = {
	AnimationId: string,
	Hitbox: HitboxData,
	Damage: number,
	StaminaCost: number,
	HitStun: number,
	PostureDamage: number?,
}

export type ActionMetadata = {
	ActionName: string,
	ActionType: string,
	AnimationSet: string?,
	AnimationId: string?,
	ComboIndex: number?,

	Damage: number?,
	StaminaCost: number?,
	HitStun: number?,
	PostureDamage: number?,

	HitboxSize: Vector3?,
	HitboxOffset: Vector3?,

	Feintable: boolean?,
	FeintEndlag: number?,
	FeintCooldown: number?,
	ActionCooldown: number?,
	ComboEndlag: number?,
	ComboResetTime: number?,
	StaminaCostHitReduction: number?,

	FallbackHitStart: number?,
	FallbackHitEnd: number?,
	FallbackLength: number?,

	[string]: any,
}

export type ActionContext = {
	Entity: Entity,
	RawInput: string?,
	InputData: { [string]: any },
	Metadata: ActionMetadata,
	StartTime: number,
	Interrupted: boolean,
	InterruptReason: string?,
	InterruptedContext: ActionContext?,
	CustomData: { [string]: any },
}

export type ActionDefinition = {
	ActionName: string,
	ActionType: "Attack" | "Defensive" | "Movement" | "Utility",
	RequiresActiveAction: boolean?,
	DefaultMetadata: ActionMetadata?,

	BuildMetadata: ((Entity: Entity, InputData: { [string]: any }?) -> ActionMetadata?)?,
	CanExecute: ((Context: ActionContext) -> (boolean, string?))?,
	OnStart: ((Context: ActionContext) -> ())?,
	OnExecute: (Context: ActionContext) -> (),
	OnHit: ((Context: ActionContext, Target: Entity, HitIndex: number) -> ())?,
	OnInterrupt: ((Context: ActionContext) -> ())?,
	OnComplete: ((Context: ActionContext) -> ())?,
	OnCleanup: ((Context: ActionContext) -> ())?,
}

export type HitResult = {
	Target: Entity,
	Damage: number,
	HitStun: number,
	PostureDamage: number,
	WasBlocked: boolean,
	WasParried: boolean,
	HitPosition: Vector3?,
}

export type CombatEvent = {
	Entity: Entity,
	ActionName: string?,
	Context: ActionContext?,
	Target: Entity?,
	HitResult: HitResult?,
	Reason: string?,
	[string]: any,
}

return nil