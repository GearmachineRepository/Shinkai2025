--!strict

local StaminaBalance = {
	StaminaCosts = {
		SPRINT = 8,
		JOG = 4,
	},

	Regeneration = {
		RATE = 6,
		DELAY = 0.5,
	},

	Exhaustion = {
		THRESHOLD = 10,
	},

	StutterStep = {
		GRACE_PERIOD = 0.15,
		REDUCTION_PERCENT = 100,
		COOLDOWN = 0.1,
	},

	Sync = {
		QUANTUM = 0.10,
		UPDATE_THRESHOLD = 0.01,
		SYNC_RATE_SECONDS = 0.10,
	},
}

return StaminaBalance
