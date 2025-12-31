--!strict

local StatBalance = {
	Defaults = {
		Health = 100,
		MaxHealth = 100,
		Stamina = 75,
		MaxStamina = 75,
		Posture = 0,
		MaxPosture = 100,
		CarryWeight = 0,
		MaxCarryWeight = 100,
		Armor = 0,
		PhysicalResistance = 0,
		BodyFatigue = 0,
		MaxBodyFatigue = 100,
		Hunger = 75,
		MaxHunger = 75,
		Fat = 0,
		Muscle = 0,
		Durability = 0,
		RunSpeed = 28,
		JumpPower = 25,
		StrikingPower = 0,
		StrikeSpeed = 0,
		StunDuration = 0,
	},

	MovementSpeeds = {
		WalkSpeed = 8,
		JumpPower = 35,
		JogSpeedPercent = 0.625,
		JumpCooldownSeconds = 2
	},

	Caps = {
		TOTAL_SOFT_CAP_STARS = 90,
		MAX_STARS_PER_STAT = 15,
		HARD_CAP_TOTAL_STARS = 35,
		POINTS_PER_STAR = 1,
	},

	StarBonuses = {
		MaxStamina = 15,
		Durability = 8,
		RunSpeed = 0.25,
		StrikingPower = 10,
		StrikeSpeed = 0.08,
		Muscle = 12,
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

	StarTiers = {
		{ Min = 0, Max = 4, Name = "Bronze", Color = Color3.fromRGB(205, 127, 50) },
		{ Min = 5, Max = 9, Name = "Silver", Color = Color3.fromRGB(192, 192, 192) },
		{ Min = 10, Max = 14, Name = "Gold", Color = Color3.fromRGB(224, 198, 79) },
		{ Min = 15, Max = 19, Name = "Platinum", Color = Color3.fromRGB(113, 153, 172) },
		{ Min = 20, Max = 24, Name = "Emerald", Color = Color3.fromRGB(80, 200, 120) },
		{ Min = 25, Max = 29, Name = "Diamond", Color = Color3.fromRGB(116, 245, 250) },
		{ Min = 30, Max = math.huge, Name = "Champion", Color = Color3.fromRGB(207, 63, 171) },
	},
}

return StatBalance
