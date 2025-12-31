--!strict

local StaminaBalance = {
	StaminaCosts = {
		SPRINT = 6,
		JOG = 3,
	},

	Regeneration = {
		RATE = 6,
		DELAY = 0.25,
	},

	Exhaustion = {
		THRESHOLD = 10,
	},

	Sprint = {
		COOLDOWN_SECONDS = 0.5,
		MIN_STAMINA_BUFFER = 0,
		RAMP_DURATION_SECONDS = 0.25,
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