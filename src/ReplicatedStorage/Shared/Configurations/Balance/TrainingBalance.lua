--!strict

local TrainingBalance = {
	FatigueSystem = {
		MAX_FATIGUE = 100,
		TRAINING_LOCKOUT_PERCENT = 65,
		XP_TO_FATIGUE_RATIO = 0.1,
		RECOVERY_LOCATIONS = {"Apothecary", "Hospital"},
	},

	XPRates = {
		BASE_RATE = 1.0,
		AFTER_SOFT_CAP_MULTIPLIER = 0.2,
		PREMIUM_MULTIPLIER = 1.08,
	},

	HungerSystem = {
		MAX_HUNGER = 75,
		STARTING_HUNGER = 45,
		DECAY_RATE = 0.1,
		STAMINA_TO_HUNGER_RATIO = 0.05,
		CRITICAL_THRESHOLD = 20,
		MUSCLE_LOSS_THRESHOLD = 20,
		MUSCLE_LOSS_RATE_PER_SECOND = 0.1,
		FAT_TO_MUSCLE_CONVERSION = 1.0,
		STAT_GAIN_THRESHOLD = 30,
		STAT_GAIN_MULTIPLIER_NORMAL = 1.0,
		STAT_GAIN_MULTIPLIER_STARVING = 0.5,
	},

	MuscleTraining = {
		REQUIRES_FAT = true,
		FAT_CONSUMPTION_RATIO = 1.0,
		AFFECTS_RUN_SPEED = true,
		AFFECTS_STRIKE_SPEED = true,
	},

	TrainingTypes = {
		Stamina = {
			ActivityName = "Running",
			BaseXPPerSecond = 1.25,
			StaminaDrain = 4,
			NonmachineMultiplier = 0.15,
		},
		Durability = {
			ActivityName = "Conditioning",
			BaseXPPerSecond = 8,
			StaminaDrain = 3,
		},
		RunSpeed = {
			ActivityName = "Sprinting",
			BaseXPPerSecond = 1.25,
			StaminaDrain = 7,
			NonmachineMultiplier = 0.15,
		},
		StrikingPower = {
			ActivityName = "Heavy Bag",
			BaseXPPerSecond = 9,
			StaminaDrain = 6,
		},
		StrikeSpeed = {
			ActivityName = "Speed Bag",
			BaseXPPerSecond = 11,
			StaminaDrain = 4,
		},
		Muscle = {
			ActivityName = "Weight Training",
			BaseXPPerSecond = 7,
			StaminaDrain = 8,
			RequiresFat = true,
		},
	},

	FatSystem = {
		MAX_FAT = 650,
		FAT_GAIN_THRESHOLD_PERCENT = 70,
		FAT_GAIN_RATE_PER_SECOND = 1.15,
		FAT_LOSS_RATE_PER_SECOND = 0.15,
		HEALTH_PER_FAT = 13,
		FAT_RUNSPEED_REDUCTION_PER_FAT = 0.04,
		RUNSPEED_MAX_PENALTY_PERCENT = 40,
		STRIKESPEED_PENALTY_PER_FAT = 0.01,
	},

	MuscleSystem = {
		OVER_TRAINING_THRESHOLD_PERCENT = 80,
		STRIKINGPOWER_PER_MUSCLE = 0.5,
		RUNSPEED_PENALTY_PER_MUSCLE = 0.02,
		STRIKESPEED_PENALTY_PER_MUSCLE = 0.015,
		OVERTRAINED_SP_PENALTY_PERCENT = 50,
	},
}

return TrainingBalance