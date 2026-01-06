--!strict

local HungerBalance = {
	Hunger = {
		MaxHunger = 75,
		StartingHunger = 45,
		DecayRate = 0.05,
		StaminaToHungerRatio = 0.05,
		CriticalThreshold = 20,
		StatGainThreshold = 30,
		StatGainMultiplierNormal = 1.0,
		StatGainMultiplierStarving = 0.5,
	},

	MuscleLoss = {
		Threshold = 20,
		RatePerSecond = 0.1,
		FatToMuscleConversion = 1.0,
	},

	Sweat = {
		StaminaThresholdPercent = 0.75,
		ActivityTimeoutSeconds = 5,
		CooldownDurationSeconds = 120,
		StatGainMultiplier = 1.15,
		HungerDrainMultiplier = 1.25,
	},
}

return HungerBalance