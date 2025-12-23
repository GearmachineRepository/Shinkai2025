--!strict

local EnsembleTypes = require(game.ServerScriptService.Server.Ensemble.Types)

export type Entity = EnsembleTypes.Entity

export type ActionContext = {
    Entity: EnsembleTypes.Entity,
    InputData: { [string]: any }?,
    Metadata: ActionMetadata?,
    StartTime: number,
    Interrupted: boolean,
    InterruptReason: string?,
    CustomData: { [string]: any },
}

export type ActionMetadata = {
    ActionName: string,
    BaseDamage: number?,
    StaminaCost: number?,
    Duration: number?,
    Cooldown: number?,
    AnimationId: string?,
    HitboxSize: Vector3?,
    HitboxOffset: CFrame?,
    -- Skill-specific overrides from inventory
    SkillEdits: {
        Range: number?,
        Speed: number?,
        Cooldown: number?,
        Power: number?,
    }?,
    -- Any other data from inventory item
    [string]: any,
}

export type ActionDefinition = {
    ActionName: string,
    ActionType: "Attack" | "Ability" | "Defensive" | "Movement",
    DefaultMetadata: ActionMetadata,

    CanExecute: ((Context: ActionContext) -> (boolean, string?))?,
    OnStart: ((Context: ActionContext) -> ())?,
    OnExecute: (Context: ActionContext) -> (),
    OnHit: ((Context: ActionContext, Target: EnsembleTypes.Entity, HitIndex: number) -> ())?,
    OnInterrupt: ((Context: ActionContext) -> ())?,
    OnComplete: ((Context: ActionContext) -> ())?,
    OnCleanup: ((Context: ActionContext) -> ())?,
}

export type StateHandler = {
    OnEnter: ((Entity: EnsembleTypes.Entity, EventData: any) -> ())?,
    OnExit: ((Entity: EnsembleTypes.Entity, EventData: any) -> ())?,
    OnUpdate: ((Entity: EnsembleTypes.Entity, DeltaTime: number) -> ())?,
}

export type HitboxConfig = {
    Owner: EnsembleTypes.Entity,
    Size: Vector3,
    Offset: CFrame,
    Duration: number,
    OnHit: (Target: EnsembleTypes.Entity) -> (),
    MaxTargets: number?,
    IgnoreList: { Model }?,
    Shape: "Box" | "Sphere"?,
}

return nil