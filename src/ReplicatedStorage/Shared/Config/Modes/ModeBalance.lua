--!strict

local ModeBalance = {
	Removal = {
		Duration = 35,
		Cooldown = 60,

		StatBoosts = {
			Durability = 1,
			RunSpeed = 1,
			StrikingPower = 1,
			StrikeSpeed = 1,
			Muscle = 1,
		},

		Bonuses = {
			HealthBoostPercent = 20,
			StaminaBoostPercent = 20,
			KureSkillCooldownReduction = 15,
		},

		TrainablePercent = {
			StartPercent = 5,
			MaxPercentRegular = 75,
			MaxPercentWu = 100,
			TrainingRate = 0.1,
		},
	},

	Advance = {
		Duration = 20,
		Cooldown = 60,

		StatBoosts = {
			StrikingPower = 2,
			RunSpeed = 2,
			StrikeSpeed = 2,
		},

		Bonuses = {
			StaminaBoostPercent = 40,
		},

		Penalties = {
			DamageOnEnd = 15,
		},
	},

	Flow = {
		Duration = 27,
		Cooldown = 50,

		StatBoosts = {
			MaxStamina = 0.5,
			Durability = 0.5,
			RunSpeed = 0.5,
			StrikingPower = 0.5,
			StrikeSpeed = 0.5,
			Muscle = 0.5,
		},

		Bonuses = {
			HealthBoostPercent = 15,
			StaminaBoostPercent = 15,
		},
	},

	Guihan = {
		Duration = 40,
		Cooldown = 60,

		StatBoosts = {
			Durability = 1.5,
			RunSpeed = 1.5,
			StrikingPower = 1.5,
			StrikeSpeed = 1.5,
			Muscle = 1.5,
		},

		Bonuses = {
			HealthBoostPercent = 25,
			StaminaBoostPercent = 25,
			KureSkillCooldownReduction = 20,
		},

		TrainablePercent = {
			StartPercent = 5,
			MaxPercent = 100,
			TrainingRate = 0.1,
		},
	},
}

return ModeBalance