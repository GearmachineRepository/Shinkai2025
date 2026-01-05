--!strict

local ProgressionBalance = {
	XPRates = {
		BaseRate = 1.0,
		AfterSoftCapMultiplier = 0.2,
		PremiumMultiplier = 1.08,
	},

	Caps = {
		TotalSoftCapStars = 90,
		MaxStarsPerStat = 15,
		HardCapTotalStars = 35,
		PointsPerStar = 1,
	},

	XPThresholds = {
		MaxStamina = 100,
		Durability = 100,
		RunSpeed = 100,
		StrikingPower = 100,
		StrikeSpeed = 100,
		Muscle = 100,
	},

	XPTierIncrement = {
		MaxStamina = 100,
		Durability = 100,
		RunSpeed = 100,
		StrikingPower = 100,
		StrikeSpeed = 100,
		Muscle = 100,
	},

	XPTierSize = 5,

	StarBonuses = {
		MaxStamina = 15,
		Durability = 8,
		RunSpeed = 0.25,
		StrikingPower = 10,
		StrikeSpeed = 0.08,
		Muscle = 12,
	},

	StarTiers = {
		{ Min = 0, Max = 4, Name = "Bronze", Color = { R = 205, G = 127, B = 50 } },
		{ Min = 5, Max = 9, Name = "Silver", Color = { R = 192, G = 192, B = 192 } },
		{ Min = 10, Max = 14, Name = "Gold", Color = { R = 224, G = 198, B = 79 } },
		{ Min = 15, Max = 19, Name = "Platinum", Color = { R = 113, G = 153, B = 172 } },
		{ Min = 20, Max = 24, Name = "Emerald", Color = { R = 80, G = 200, B = 120 } },
		{ Min = 25, Max = 29, Name = "Diamond", Color = { R = 116, G = 245, B = 250 } },
		{ Min = 30, Max = 999, Name = "Champion", Color = { R = 207, G = 63, B = 171 } },
	},

	TrainableStats = {
		"MaxStamina",
		"Durability",
		"RunSpeed",
		"StrikingPower",
		"StrikeSpeed",
		"Muscle",
	},
}

return ProgressionBalance