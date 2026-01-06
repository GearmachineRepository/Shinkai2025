--!strict

local TrainingTypesBalance = {
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
}

return TrainingTypesBalance