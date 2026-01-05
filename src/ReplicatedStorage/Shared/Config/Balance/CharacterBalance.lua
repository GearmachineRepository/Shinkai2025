--!strict

local CharacterBalance = {
	Stamina = {
		SprintCost = 5,
		JogCost = 3,
		RegenRate = 5,
		RegenDelay = 0.15,
		ExhaustionThreshold = 10,
	},

	Sprint = {
		CooldownSeconds = 0.25,
		MinStaminaBuffer = 0,
		RampDurationSeconds = 0.00,
	},

	StutterStep = {
		GracePeriod = 0.25,
		ReductionPercent = 100,
		Cooldown = 0.1,
	},

	HealthRegen = {
		Rate = 1,
		Delay = 5,
		Interval = 0.1,
	},

	Movement = {
		WalkSpeed = 8,
		BaseRunSpeed = 28,
		JogSpeedPercent = 0.625,
		JumpPower = 35,
		JumpCooldownSeconds = 2,
	},
}

return CharacterBalance