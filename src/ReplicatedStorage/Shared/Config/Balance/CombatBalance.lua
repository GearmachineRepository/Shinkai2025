--!strict

local CombatBalance = {
	Blocking = {
		DamageReduction = 0.95,
		StaminaDrainOnHit = 5,
		StaminaDrainScalar = 1.0,
		GuardBreakDuration = 1.5,
		CanHoldIndefinitely = true,
		MovementSpeedMultiplier = 0.5,
		BlockHitDuration = 0.3,
		BlockAngle = 180,
	},

	Attacking = {
		MovementSpeedMultiplier = 0.65,
		ClashWindowSeconds = 0.30,
	},

	Stunned = {
		MovementSpeedMultiplier = 0.3,
	},

	PerfectBlock = {
		WindowSeconds = 0.325,
		CooldownSeconds = 6,
		SpamCooldownSeconds = 12,
		NegatesAllDamage = true,
		StaggerAttacker = true,
		StaggerDuration = 1.25,
		MaxAngle = 360,
	},

	Counter = {
		WindowSeconds = 0.325,
		CooldownSeconds = 6,
		SpamCooldownSeconds = 12,
		NegatesAllDamage = true,
		StaggerAttacker = true,
		StaggerDuration = 0.8,
		MaxAngle = 180,
	},

	Parry = {
		WindowSeconds = 0.15,
		CooldownSeconds = 10,
		StunDuration = 0.7,
		StaminaCost = 8,
		RequiresFacing = true,
		DeflectsAttack = true,
	},

	StaminaSystem = {
		CollapseOnZero = true,
		CollapseDuration = 15,
		BlockHitDrain = 5,
		ParryCost = 8,
	},

	DownState = {
		ImmunityWindowSeconds = 10,
		StandupStaminaCost = 10,
		VulnerableToSpecificMoves = true,
	},

	DamageMultipliers = {
		Head = 1.5,
		Torso = 1.0,
		Legs = 0.8,
	},

	Posture = {
		Max = 100,
		BaseDamage = 15,
		WeightMultiplier = 2,
		BaseRecovery = 0.8,
		IdleDelay = 1.5,
		GuardbreakStun = 0.7,
		BlockedMultiplier = 1.0,
		HitMultiplier = 0.3,
		BrokenArmorBonus = 0.5,
		PerfectParryRecovery = 20,
	},

	ParryMechanics = {
		ConeAngle = 140,
		SuccessStun = 0.35,
		FailRecoil = 0.25,
		FailPosturePercent = 0.18,
	},

	BlockMechanics = {
		ConeAngle = 140,
		PostureMultiplier = 1.0,
		DamageReduction = 0.5,
	},

	Riposte = {
		WindowSeconds = 0.5,
		DamageMultiplier = 1.5,
	},

	Armor = {
		DurabilityLossLight = 1,
		DurabilityLossHeavy = 2,
	},

	ArmorResistances = {
		Leather = { Slash = 0.1, Pierce = 0.05, Blunt = 0.15 },
		Mail = { Slash = 0.3, Pierce = 0.2, Blunt = 0.1 },
		Plate = { Slash = 0.4, Pierce = 0.35, Blunt = 0.2 },
	},

	Validation = {
		MaxAttackDuration = 4.0,
		MinAttackDuration = 0.1,
		EndlagWindow = 0.25,
		RateLimit = 0.15,
		LatencyTolerance = 0.15,
		RangeTolerance = 2.5,
	},

	Momentum = {
		Threshold = 5,
		DamageDivisor = 20,
	},
}

return CombatBalance