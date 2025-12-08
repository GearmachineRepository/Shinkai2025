--!strict

local StaminaBalance = {
	StaminaCosts = {
		SPRINT = 8,
		JOG = 4,
	},

	Regeneration = {
		RATE = 5,
		DELAY = 1.5,
	},

	Exhaustion = {
		THRESHOLD = 10,
	},

	StutterStep = {
		GRACE_PERIOD = 0.15,
		REDUCTION_PERCENT = 100,
		COOLDOWN = 0.1,
	},
}

return StaminaBalance