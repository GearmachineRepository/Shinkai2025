--!strict

local StaminaBalance = {
	StaminaCosts = {
		SPRINT = 5,
		JOG = 3,
	},

	Regeneration = {
		RATE = 8,
		DELAY = 0.15,
	},

	Exhaustion = {
		THRESHOLD = 10,
	},

	Sprint = {
		COOLDOWN_SECONDS = 0.25,
		MIN_STAMINA_BUFFER = 0,
		RAMP_DURATION_SECONDS = 0.00,
	},

	StutterStep = {
		GRACE_PERIOD = 0.25,
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