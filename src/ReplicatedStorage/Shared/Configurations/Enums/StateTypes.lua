--!strict

local StateTypes = {
    RAGDOLLED = "Ragdolled",
    ATTACKING = "Attacking",
    INVULNERABLE = "Invulnerable",
    STUNNED = "Stunned",
    BLOCKING = "Blocking",
    PARRYING = "Parrying",
    PARRIED = "Parried",
    CLASHING = "Clashing",
    DOWNED = "Downed",
    KILLED = "Killed",
    SPRINTING = "Sprinting",
    JOGGING = "Jogging",
    JUMPING = "Jumping",
    FALLING = "Falling",
    IN_CUTSCENE = "InCutscene",
	GUARD_BROKEN = "Guardbroken",
    RIPOSTE_WINDOW = "RiposteWindow",
    DODGING = "Dodging",
    IFRAME = "Iframe",
    MODE_ACTIVE = "ModeActive",
    BLOCK_HIT = "BlockHit",
    ONHIT = "OnHit",
    STAGGERED = "Staggered",
    BLINDED = "Blinded",
    BLEEDING = "Bleeding",
    EXHAUSTED = "Exhausted",
    SLUGGISH = "Sluggish",
    FATIGUED = "Fatigued",
    DIZZY = "Dizzy",
    MOVEMENT_LOCKED = "MovementLocked",
}

local ReplicationConfig = {
    [StateTypes.SPRINTING] = "LocalOnly",
    [StateTypes.JOGGING] = "LocalOnly",
    [StateTypes.JUMPING] = "LocalOnly",
    [StateTypes.FALLING] = "LocalOnly",
}

function StateTypes.GetReplicationMode(StateName: string): string
    return ReplicationConfig[StateName] or "Replicated"
end

return StateTypes