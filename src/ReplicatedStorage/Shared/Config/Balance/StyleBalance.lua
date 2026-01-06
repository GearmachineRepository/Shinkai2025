--!strict

export type DamageScalingConfig = {
	StrikingPower: number?,
	StrikeSpeed: number?,
	Muscle: number?,
	Fat: number?,
}

export type StyleScalingConfig = {
	BaseDamage: number,
	BaseSpeed: number,
	BaseRange: number,
	BaseStun: number,
	BaseStaminaCost: number,
	DamageScaling: DamageScalingConfig,
}

local StyleBalance: { [string]: StyleScalingConfig } = {
	Karate = {
		BaseDamage = 1.15,
		BaseSpeed = 0.9,
		BaseRange = 1.0,
		BaseStun = 1.0,
		BaseStaminaCost = 0.85,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.3,
		},
	},

	KungFu = {
		BaseDamage = 1.0,
		BaseSpeed = 1.0,
		BaseRange = 0.9,
		BaseStun = 0.85,
		BaseStaminaCost = 1.0,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.4,
		},
	},

	Boxing = {
		BaseDamage = 0.9,
		BaseSpeed = 1.15,
		BaseRange = 0.9,
		BaseStun = 0.85,
		BaseStaminaCost = 1.0,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.3,
		},
	},

	Judo = {
		BaseDamage = 0.9,
		BaseSpeed = 1.0,
		BaseRange = 1.0,
		BaseStun = 1.2,
		BaseStaminaCost = 0.85,
		DamageScaling = {
			StrikingPower = 0.25,
			Muscle = 0.5,
		},
	},

	Brawl = {
		BaseDamage = 1.15,
		BaseSpeed = 0.85,
		BaseRange = 1.0,
		BaseStun = 1.2,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.5,
			Muscle = 0.5,
		},
	},

	Wrestling = {
		BaseDamage = 1.0,
		BaseSpeed = 0.85,
		BaseRange = 0.9,
		BaseStun = 1.2,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.25,
			Muscle = 0.5,
			Fat = 0.3,
		},
	},

	MuayThai = {
		BaseDamage = 1.15,
		BaseSpeed = 0.9,
		BaseRange = 1.0,
		BaseStun = 1.0,
		BaseStaminaCost = 1.0,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.4,
		},
	},

	Taekwondo = {
		BaseDamage = 1.0,
		BaseSpeed = 0.9,
		BaseRange = 1.15,
		BaseStun = 1.0,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.3,
		},
	},

	Kendo = {
		BaseDamage = 1.0,
		BaseSpeed = 0.9,
		BaseRange = 1.2,
		BaseStun = 0.85,
		BaseStaminaCost = 1.0,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.25,
		},
	},

	Koei = {
		BaseDamage = 1.0,
		BaseSpeed = 1.15,
		BaseRange = 0.85,
		BaseStun = 0.85,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.3,
			StrikeSpeed = 0.4,
		},
	},

	Raishin = {
		BaseDamage = 0.9,
		BaseSpeed = 1.2,
		BaseRange = 1.0,
		BaseStun = 0.85,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.4,
			StrikeSpeed = 0.5,
		},
	},

	Kure = {
		BaseDamage = 1.15,
		BaseSpeed = 0.9,
		BaseRange = 0.9,
		BaseStun = 1.0,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.5,
			Muscle = 0.5,
		},
	},

	Gaoh = {
		BaseDamage = 1.0,
		BaseSpeed = 1.15,
		BaseRange = 0.85,
		BaseStun = 0.85,
		BaseStaminaCost = 1.0,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.4,
		},
	},

	Niko = {
		BaseDamage = 1.0,
		BaseSpeed = 1.0,
		BaseRange = 0.85,
		BaseStun = 1.0,
		BaseStaminaCost = 1.2,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.4,
			StrikeSpeed = 0.25,
		},
	},

	Fists = {
		BaseDamage = 1.0,
		BaseSpeed = 1.0,
		BaseRange = 1.0,
		BaseStun = 1.0,
		BaseStaminaCost = 1.0,
		DamageScaling = {
			StrikingPower = 0.4,
			Muscle = 0.4,
		},
	},
}

local PASSIVE_MULTIPLIERS = {
	WrestlingMuscleDamageBonus = 1.15,
}

local StyleBalanceModule = {
	Styles = StyleBalance,
	PassiveMultipliers = PASSIVE_MULTIPLIERS,
}

return StyleBalanceModule