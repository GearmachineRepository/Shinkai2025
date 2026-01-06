--!strict

local CombatEvents = {
	ActionConfiguring = "ActionConfiguring",
	ActionStarted = "ActionStarted",
	ActionCompleted = "ActionCompleted",
	ActionInterrupted = "ActionInterrupted",

	AttackStarted = "AttackStarted",
	AttackHit = "AttackHit",
	AttackBlocked = "AttackBlocked",
	AttackParried = "AttackParried",
	AttackMissed = "AttackMissed",
	AttackCompleted = "AttackCompleted",

	HitWindowOpened = "HitWindowOpened",
	HitWindowClosed = "HitWindowClosed",

	BlockStarted = "BlockStarted",
	BlockEnded = "BlockEnded",
	BlockHit = "BlockHit",
	BlockMissed = "BlockMissed",

	GuardBroken = "GuardBroken",
	GuardBreakRecovered = "GuardBreakRecovered",

	WindowOpened = "WindowOpened",
	WindowClosed = "WindowClosed",
	WindowTriggered = "WindowTriggered",

	ParrySuccess = "ParrySuccess",
	ParryFailed = "ParryFailed",
	PerfectGuardInitiated = "PerfectGuardInitiated",
	PerfectGuardSuccess = "PerfectGuardSuccess",

	CounterInitiated = "CounterInitiated",
	CounterExecuted = "CounterExecuted",
	CounterHit = "CounterHit",

	FeintExecuted = "FeintExecuted",

	DodgeStarted = "DodgeStarted",
	DodgeCompleted = "DodgeCompleted",
	DodgeSuccessful = "DodgeSuccessful",
	DodgeIFramesStarted = "DodgeIFramesStarted",
	DodgeIFramesEnded = "DodgeIFramesEnded",
	DodgeCancelExecuted = "DodgeCancelExecuted",

	KnockbackStarted = "KnockbackStarted",
	KnockbackImpact = "KnockbackImpact",

	ClashOccurred = "ClashOccurred",

	DamageDealt = "DamageDealt",
	DamageBlocked = "DamageBlocked",
	DamageTaken = "DamageTaken",
	DamageDodged = "DamageDodged",

	StunApplied = "StunApplied",
	StunRecovered = "StunRecovered",

	StaminaConsumed = "StaminaConsumed",
	StaminaRefunded = "StaminaRefunded",

	ComboAdvanced = "ComboAdvanced",
	ComboReset = "ComboReset",
	ComboFinished = "ComboFinished"
}

return CombatEvents