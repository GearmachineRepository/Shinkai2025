--!strict

local CombatEvents = {
	ActionConfiguring = "ActionConfiguring",
	ActionStarted = "ActionStarted",
	ActionCompleted = "ActionCompleted",
	ActionInterrupted = "ActionInterrupted",
	ActionCancelled = "ActionCancelled",

	AttackStarted = "AttackStarted",
	AttackHit = "AttackHit",
	AttackMissed = "AttackMissed",
	AttackBlocked = "AttackBlocked",
	AttackParried = "AttackParried",

	FeintExecuted = "FeintExecuted",
	FeintFailed = "FeintFailed",

	BlockStarted = "BlockStarted",
	BlockEnded = "BlockEnded",
	BlockHit = "BlockHit",
	GuardBroken = "GuardBroken",

	ParryAttempted = "ParryAttempted",
	ParrySuccess = "ParrySuccess",
	ParryFailed = "ParryFailed",
	ParryWindowOpened = "ParryWindowOpened",
	ParryWindowClosed = "ParryWindowClosed",

	PerfectGuardAttempted = "PerfectGuardAttempted",
	PerfectGuardSuccess = "PerfectGuardSuccess",
	PerfectGuardFailed = "PerfectGuardFailed",

	CounterAttempted = "CounterAttempted",
	CounterExecuted = "CounterExecuted",
	CounterHit = "CounterHit",
	CounterFailed = "CounterFailed",

	DodgeStarted = "DodgeStarted",
	DodgeCompleted = "DodgeCompleted",
	DodgeSuccessful = "DodgeSuccessful",

	ClashOccurred = "ClashOccurred",

	ComboAdvanced = "ComboAdvanced",
	ComboReset = "ComboReset",
	ComboFinished = "ComboFinished",

	HitWindowOpened = "HitWindowOpened",
	HitWindowClosed = "HitWindowClosed",
	HitRegistered = "HitRegistered",

	DamageDealt = "DamageDealt",
	DamageTaken = "DamageTaken",
	DamageBlocked = "DamageBlocked",
	DamageReduced = "DamageReduced",

	PostureDamageDealt = "PostureDamageDealt",
	PostureDamageTaken = "PostureDamageTaken",
	PostureBroken = "PostureBroken",
	PostureRecovered = "PostureRecovered",

	StunApplied = "StunApplied",
	StunEnded = "StunEnded",
	HitStunApplied = "HitStunApplied",

	StaminaConsumed = "StaminaConsumed",
	StaminaRefunded = "StaminaRefunded",

	CooldownStarted = "CooldownStarted",
	CooldownEnded = "CooldownEnded",

	CombatEntered = "CombatEntered",
	CombatExited = "CombatExited",
}

return CombatEvents