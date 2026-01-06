--!strict

local BodyBalance = {
	Fat = {
		MaxFat = 650,
		MaxFatJigoro = 750,
		GainThresholdPercent = 70,
		GainRatePerSecond = 1.15,
		LossRatePerSecond = 0.15,
		HealthPerFat = 13,
		RunSpeedReductionPerFat = 0.04,
		RunSpeedMaxPenaltyPercent = 40,
		StrikeSpeedPenaltyPerFat = 0.01,
	},

	Muscle = {
		OverTrainingThresholdPercent = 80,
		StrikingPowerPerMuscle = 0.5,
		RunSpeedPenaltyPerMuscle = 0.02,
		StrikeSpeedPenaltyPerMuscle = 0.015,
		OvertrainedStrikingPowerPenaltyPercent = 50,
	},

	MuscleTraining = {
		RequiresFat = true,
		FatConsumptionRatio = 1.0,
		AffectsRunSpeed = true,
		AffectsStrikeSpeed = true,
	},

	BodyScaling = {
		ScaleMin = 1.0,
		ScaleMax = 1.30,
		MuscleScaleMultiplier = 0.0005,
		FatScaleMultiplier = 0.00035,
	},

	DamageReduction = {
		ReductionPerDurabilityPoint = 0.005,
		MaxReductionPercent = 60,
	},
}

return BodyBalance