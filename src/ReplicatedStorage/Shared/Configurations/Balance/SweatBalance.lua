--!strict

local SweatBalance = {
	Thresholds = {
		STAMINA_THRESHOLD_PERCENT = 0.75,
		ACTIVITY_TIMEOUT_SECONDS = 5,
	},

	Cooldown = {
		DURATION_SECONDS = 120,
	},

	Multipliers = {
		STAT_GAIN = 1.15,
		HUNGER_DRAIN = 1.25,
	},
}

return SweatBalance
