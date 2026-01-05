--!strict

local FatigueBalance = {
	Fatigue = {
		MaxFatigue = 100,
		TrainingLockoutPercent = 65,
		XPToFatigueRatio = 0.1,
	},

	Rest = {
		TimeToFullRest = 300,
		PremiumTimeToFullRest = 270,
		RecoveryLocations = { "Apothecary", "Hospital" },
	},

	Updates = {
		Interval = 1.0,
		Threshold = 0.1,
	},
}

return FatigueBalance