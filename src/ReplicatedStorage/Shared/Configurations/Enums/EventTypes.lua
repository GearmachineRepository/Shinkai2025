--!strict

local EventTypes = {
	DAMAGE_TAKEN = "DamageTaken",
	DAMAGE_DEALT = "DamageDealt",
	ATTACK_STARTED = "AttackStarted",
	ATTACK_HIT = "AttackHit",
	KILLED_ENEMY = "KilledEnemy",
	PARRY_SUCCESS = "ParrySuccess",
	PARRY_FAILED = "ParryFailed",
	BLOCK_SUCCESS = "BlockSuccess",
	PERFECT_BLOCK = "PerfectBlock",
	POSTURE_BREAK = "PostureBreak",
	RIPOSTE_STARTED = "RiposteStarted",
	SPRINT_STARTED = "SprintStarted",
	SPRINT_STOPPED = "SprintStopped",
	JOG_STARTED = "JogStarted",
	JOG_STOPPED = "JogStopped",
	DODGE_STARTED = "DodgeStarted",
	SKILL_USED = "SkillUsed",
	MODE_ACTIVATED = "ModeActivated",
	MODE_DEACTIVATED = "ModeDeactivated",
	STAMINA_DEPLETED = "StaminaDepleted",
	HUNGER_CRITICAL = "HungerCritical",
}

return EventTypes