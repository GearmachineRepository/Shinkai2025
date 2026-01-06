--!strict

local StyleConfig = {}

export type HitboxData = {
	Size: Vector3,
	Offset: Vector3,
}

export type AttackData = {
	AnimationId: string,
	Hitbox: HitboxData,
	Damage: number,
	Knockback: number?,
	StaminaCost: number,
	HitStun: number,
	Flag: string?,
	Flags: { string }?,
}

export type DamageScalingConfig = {
	StrikingPower: number?,
	StrikeSpeed: number?,
	Muscle: number?,
	Fat: number?,
}

export type BalanceConfig = {
	BaseDamage: number,
	BaseSpeed: number,
	BaseRange: number,
	BaseStun: number,
	BaseStaminaCost: number,
	DamageScaling: DamageScalingConfig,
}

export type TimingConfig = {
	Feintable: boolean,
	FeintEndlag: number,
	FeintCooldown: number,
	HeavyAttackCooldown: number,
	ComboEndlag: number,
	ComboResetTime: number,
	StaminaCostHitReduction: number,
	FallbackHitStart: number,
	FallbackHitEnd: number,
	FallbackLength: number,
}

export type AnimationsConfig = {
	Block: string?,
	BlockHit: string?,
	Idle: string?,
	Walk: string?,
}

export type SoundsConfig = {
	Swing: string?,
	Hit: string?,
}

export type StyleDefinition = {
	DisplayName: string,
	Category: string,
	Balance: BalanceConfig,
	Timing: TimingConfig,
	M1: { AttackData },
	M2: { AttackData }?,
	Animations: AnimationsConfig,
	Sounds: SoundsConfig?,
}

local DEFAULT_BALANCE: BalanceConfig = {
	BaseDamage = 1.0,
	BaseSpeed = 1.0,
	BaseRange = 1.0,
	BaseStun = 1.0,
	BaseStaminaCost = 1.0,
	DamageScaling = {
		StrikingPower = 0.4,
		Muscle = 0.4,
	},
}

local DEFAULT_TIMING: TimingConfig = {
	Feintable = true,
	FeintEndlag = 0.25,
	FeintCooldown = 3.0,
	HeavyAttackCooldown = 2.0,
	ComboEndlag = 0.5,
	ComboResetTime = 2.0,
	StaminaCostHitReduction = 0.15,
	FallbackHitStart = 0.25,
	FallbackHitEnd = 0.55,
	FallbackLength = 1.25,
}

local PASSIVE_MULTIPLIERS = {
	WrestlingMuscleDamageBonus = 1.15,
}

local Styles: { [string]: StyleDefinition } = {
	Fists = {
		DisplayName = "Fists",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.2,
			FeintCooldown = 2.5,
			HeavyAttackCooldown = 2.0,
			ComboEndlag = 0.3,
			ComboResetTime = 1.5,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.2,
			FallbackHitEnd = 0.5,
			FallbackLength = 1.0,
		},

		M1 = {
			{
				AnimationId = "rbxassetid://120810578835776",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 3,
				HitStun = 0.2,
			},
			{
				AnimationId = "rbxassetid://135298421079091",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 3,
				HitStun = 0.2,
			},
			{
				AnimationId = "rbxassetid://90246825026625",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 4,
				HitStun = 0.25,
			},
			{
				AnimationId = "rbxassetid://71745443772185",
				Hitbox = { Size = Vector3.new(5, 4, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 8,
				StaminaCost = 5,
				HitStun = 0.3,
			},
		},

		M2 = {
			{
				AnimationId = "rbxassetid://181818",
				Hitbox = { Size = Vector3.new(5, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 15,
				StaminaCost = 10,
				HitStun = 0.45,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "FistsIdle",
			Walk = "FistsWalk",
		},

		Sounds = {
			Swing = "FistSwing",
			Hit = "FistHit",
		},
	},

	Karate = {
		DisplayName = "Karate",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.15,
			FeintCooldown = 0.5,
			HeavyAttackCooldown = 2.0,
			ComboEndlag = 1.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.25,
			FallbackHitEnd = 0.55,
			FallbackLength = 1.25,
		},

		M1 = {
			{
				AnimationId = "Karate1",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.8,
			},
			{
				AnimationId = "Karate2",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.8,
			},
			{
				AnimationId = "Karate3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.8,
			},
			{
				AnimationId = "Karate4",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.8,
				Knockback = 60,
			},
		},

		M2 = {
			{
				AnimationId = "KarateHeavy",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 4,
				HitStun = 0.65,
				Knockback = 80,
				Flag = "GuardBreak",
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "KarateIdle",
			Walk = "KarateWalk",
		},

		Sounds = {
			Swing = "KarateSwing",
			Hit = "KarateHit",
		},
	},

	MuayThai = {
		DisplayName = "Muay Thai",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.3,
			FeintCooldown = 3.5,
			HeavyAttackCooldown = 2.5,
			ComboEndlag = 0.6,
			ComboResetTime = 2.5,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.3,
			FallbackHitEnd = 0.6,
			FallbackLength = 1.5,
		},

		M1 = {
			{
				AnimationId = "MuayThai1",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 10,
				StaminaCost = 5,
				HitStun = 0.35,
			},
			{
				AnimationId = "MuayThai2",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 10,
				StaminaCost = 5,
				HitStun = 0.35,
			},
			{
				AnimationId = "MuayThai3",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 12,
				StaminaCost = 6,
				HitStun = 0.4,
			},
			{
				AnimationId = "MuayThai4",
				Hitbox = { Size = Vector3.new(6, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 16,
				StaminaCost = 7,
				HitStun = 0.5,
			},
		},

		M2 = {
			{
				AnimationId = "MuayThaiHeavy",
				Hitbox = { Size = Vector3.new(7, 6, 8), Offset = Vector3.new(0, 0, -5) },
				Damage = 25,
				StaminaCost = 14,
				HitStun = 0.6,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "MuayThaiIdle",
			Walk = "MuayThaiWalk",
		},

		Sounds = {
			Swing = "MuayThaiSwing",
			Hit = "MuayThaiHit",
		},
	},

	Boxing = {
		DisplayName = "Boxing",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.15,
			FeintCooldown = 2.0,
			HeavyAttackCooldown = 1.8,
			ComboEndlag = 0.4,
			ComboResetTime = 1.5,
			StaminaCostHitReduction = 0.2,
			FallbackHitStart = 0.15,
			FallbackHitEnd = 0.4,
			FallbackLength = 0.9,
		},

		M1 = {
			{
				AnimationId = "Boxing1",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 4,
				StaminaCost = 3,
				HitStun = 0.15,
			},
			{
				AnimationId = "Boxing2",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 4,
				StaminaCost = 3,
				HitStun = 0.15,
			},
			{
				AnimationId = "Boxing3",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "Boxing4",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 4,
				HitStun = 0.25,
				Knockback = 40,
			},
		},

		M2 = {
			{
				AnimationId = "BoxingHeavy",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 12,
				StaminaCost = 8,
				HitStun = 0.5,
				Knockback = 60,
			},
		},

		Animations = {
			Block = "BoxingBlock",
			BlockHit = "BoxingBlockHit",
			Idle = "BoxingIdle",
			Walk = "BoxingWalk",
		},

		Sounds = {
			Swing = "BoxingSwing",
			Hit = "BoxingHit",
		},
	},

	Judo = {
		DisplayName = "Judo",
		Category = "Grappling",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.25,
			FeintCooldown = 3.0,
			HeavyAttackCooldown = 2.5,
			ComboEndlag = 0.6,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.1,
			FallbackHitStart = 0.3,
			FallbackHitEnd = 0.6,
			FallbackLength = 1.3,
		},

		M1 = {
			{
				AnimationId = "Judo1",
				Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.3,
			},
			{
				AnimationId = "Judo2",
				Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.3,
			},
			{
				AnimationId = "Judo3",
				Hitbox = { Size = Vector3.new(5, 5, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 7,
				StaminaCost = 5,
				HitStun = 0.4,
			},
			{
				AnimationId = "Judo4",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 6,
				HitStun = 0.5,
				Knockback = 50,
			},
		},

		M2 = {
			{
				AnimationId = "JudoHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 14,
				StaminaCost = 12,
				HitStun = 0.7,
				Knockback = 70,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "JudoIdle",
			Walk = "JudoWalk",
		},

		Sounds = {
			Swing = "JudoSwing",
			Hit = "JudoHit",
		},
	},

	Wrestling = {
		DisplayName = "Wrestling",
		Category = "Grappling",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.3,
			FeintCooldown = 3.5,
			HeavyAttackCooldown = 3.0,
			ComboEndlag = 0.7,
			ComboResetTime = 2.5,
			StaminaCostHitReduction = 0.1,
			FallbackHitStart = 0.35,
			FallbackHitEnd = 0.65,
			FallbackLength = 1.5,
		},

		M1 = {
			{
				AnimationId = "Wrestling1",
				Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.35,
			},
			{
				AnimationId = "Wrestling2",
				Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.35,
			},
			{
				AnimationId = "Wrestling3",
				Hitbox = { Size = Vector3.new(5, 5, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 6,
				HitStun = 0.45,
			},
			{
				AnimationId = "Wrestling4",
				Hitbox = { Size = Vector3.new(6, 5, 6), Offset = Vector3.new(0, 0, -3) },
				Damage = 10,
				StaminaCost = 7,
				HitStun = 0.55,
				Knockback = 60,
			},
		},

		M2 = {
			{
				AnimationId = "WrestlingHeavy",
				Hitbox = { Size = Vector3.new(6, 6, 6), Offset = Vector3.new(0, 0, -3) },
				Damage = 18,
				StaminaCost = 14,
				HitStun = 0.8,
				Knockback = 80,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "WrestlingIdle",
			Walk = "WrestlingWalk",
		},

		Sounds = {
			Swing = "WrestlingSwing",
			Hit = "WrestlingHit",
		},
	},

	Brawl = {
		DisplayName = "Brawl",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.3,
			FeintCooldown = 3.0,
			HeavyAttackCooldown = 2.5,
			ComboEndlag = 0.6,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.1,
			FallbackHitStart = 0.3,
			FallbackHitEnd = 0.6,
			FallbackLength = 1.4,
		},

		M1 = {
			{
				AnimationId = "Brawl1",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 7,
				StaminaCost = 5,
				HitStun = 0.3,
			},
			{
				AnimationId = "Brawl2",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 7,
				StaminaCost = 5,
				HitStun = 0.3,
			},
			{
				AnimationId = "Brawl3",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 9,
				StaminaCost = 6,
				HitStun = 0.4,
			},
			{
				AnimationId = "Brawl4",
				Hitbox = { Size = Vector3.new(6, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 12,
				StaminaCost = 7,
				HitStun = 0.5,
				Knockback = 70,
			},
		},

		M2 = {
			{
				AnimationId = "BrawlHeavy",
				Hitbox = { Size = Vector3.new(6, 6, 8), Offset = Vector3.new(0, 0, -5) },
				Damage = 20,
				StaminaCost = 12,
				HitStun = 0.7,
				Knockback = 90,
				Flag = "GuardBreak",
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "BrawlIdle",
			Walk = "BrawlWalk",
		},

		Sounds = {
			Swing = "BrawlSwing",
			Hit = "BrawlHit",
		},
	},

	Taekwondo = {
		DisplayName = "Taekwondo",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.2,
			FeintCooldown = 2.5,
			HeavyAttackCooldown = 2.2,
			ComboEndlag = 0.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.25,
			FallbackHitEnd = 0.55,
			FallbackLength = 1.2,
		},

		M1 = {
			{
				AnimationId = "Taekwondo1",
				Hitbox = { Size = Vector3.new(4, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 5,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "Taekwondo2",
				Hitbox = { Size = Vector3.new(4, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 5,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "Taekwondo3",
				Hitbox = { Size = Vector3.new(5, 6, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 7,
				StaminaCost = 6,
				HitStun = 0.3,
			},
			{
				AnimationId = "Taekwondo4",
				Hitbox = { Size = Vector3.new(6, 6, 8), Offset = Vector3.new(0, 0, -5) },
				Damage = 9,
				StaminaCost = 7,
				HitStun = 0.4,
				Knockback = 55,
			},
		},

		M2 = {
			{
				AnimationId = "TaekwondoHeavy",
				Hitbox = { Size = Vector3.new(6, 7, 9), Offset = Vector3.new(0, 0, -5) },
				Damage = 16,
				StaminaCost = 12,
				HitStun = 0.6,
				Knockback = 75,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "TaekwondoIdle",
			Walk = "TaekwondoWalk",
		},

		Sounds = {
			Swing = "TaekwondoSwing",
			Hit = "TaekwondoHit",
		},
	},

	Raishin = {
		DisplayName = "Raishin",
		Category = "Clan",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.1,
			FeintCooldown = 1.5,
			HeavyAttackCooldown = 1.5,
			ComboEndlag = 0.3,
			ComboResetTime = 1.2,
			StaminaCostHitReduction = 0.2,
			FallbackHitStart = 0.1,
			FallbackHitEnd = 0.35,
			FallbackLength = 0.8,
		},

		M1 = {
			{
				AnimationId = "Raishin1",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 4,
				StaminaCost = 4,
				HitStun = 0.15,
			},
			{
				AnimationId = "Raishin2",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 4,
				StaminaCost = 4,
				HitStun = 0.15,
			},
			{
				AnimationId = "Raishin3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 5,
				StaminaCost = 5,
				HitStun = 0.2,
			},
			{
				AnimationId = "Raishin4",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.25,
				Knockback = 35,
			},
		},

		M2 = {
			{
				AnimationId = "RaishinHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 10,
				StaminaCost = 10,
				HitStun = 0.4,
				Knockback = 50,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "RaishinIdle",
			Walk = "RaishinWalk",
		},

		Sounds = {
			Swing = "RaishinSwing",
			Hit = "RaishinHit",
		},
	},

	Kure = {
		DisplayName = "Kure",
		Category = "Clan",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.2,
			FeintCooldown = 2.5,
			HeavyAttackCooldown = 2.2,
			ComboEndlag = 0.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.25,
			FallbackHitEnd = 0.5,
			FallbackLength = 1.2,
		},

		M1 = {
			{
				AnimationId = "Kure1",
				Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "Kure2",
				Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "Kure3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 6,
				HitStun = 0.3,
			},
			{
				AnimationId = "Kure4",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -3) },
				Damage = 10,
				StaminaCost = 6,
				HitStun = 0.4,
				Knockback = 55,
			},
		},

		M2 = {
			{
				AnimationId = "KureHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 18,
				StaminaCost = 12,
				HitStun = 0.6,
				Knockback = 70,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "KureIdle",
			Walk = "KureWalk",
		},

		Sounds = {
			Swing = "KureSwing",
			Hit = "KureHit",
		},
	},

	Niko = {
		DisplayName = "Niko",
		Category = "Clan",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.2,
			FeintCooldown = 2.0,
			HeavyAttackCooldown = 2.0,
			ComboEndlag = 0.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.2,
			FallbackHitEnd = 0.5,
			FallbackLength = 1.1,
		},

		M1 = {
			{
				AnimationId = "Niko1",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 5,
				HitStun = 0.2,
			},
			{
				AnimationId = "Niko2",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 5,
				HitStun = 0.2,
			},
			{
				AnimationId = "Niko3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 7,
				StaminaCost = 6,
				HitStun = 0.25,
			},
			{
				AnimationId = "Niko4",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 6,
				HitStun = 0.3,
				Knockback = 45,
			},
		},

		M2 = {
			{
				AnimationId = "NikoHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 15,
				StaminaCost = 12,
				HitStun = 0.5,
				Knockback = 60,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "NikoIdle",
			Walk = "NikoWalk",
		},

		Sounds = {
			Swing = "NikoSwing",
			Hit = "NikoHit",
		},
	},

	Gaoh = {
		DisplayName = "Gaoh",
		Category = "Clan",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.15,
			FeintCooldown = 2.0,
			HeavyAttackCooldown = 1.8,
			ComboEndlag = 0.4,
			ComboResetTime = 1.5,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.15,
			FallbackHitEnd = 0.4,
			FallbackLength = 0.95,
		},

		M1 = {
			{
				AnimationId = "Gaoh1",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "Gaoh2",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "Gaoh3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "Gaoh4",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 7,
				StaminaCost = 5,
				HitStun = 0.3,
				Knockback = 40,
			},
		},

		M2 = {
			{
				AnimationId = "GaohHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 12,
				StaminaCost = 10,
				HitStun = 0.45,
				Knockback = 55,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "GaohIdle",
			Walk = "GaohWalk",
		},

		Sounds = {
			Swing = "GaohSwing",
			Hit = "GaohHit",
		},
	},

	Koei = {
		DisplayName = "Koei",
		Category = "Clan",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.15,
			FeintCooldown = 2.0,
			HeavyAttackCooldown = 1.8,
			ComboEndlag = 0.4,
			ComboResetTime = 1.5,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.15,
			FallbackHitEnd = 0.4,
			FallbackLength = 0.9,
		},

		M1 = {
			{
				AnimationId = "Koei1",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 4,
				StaminaCost = 5,
				HitStun = 0.15,
			},
			{
				AnimationId = "Koei2",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 4,
				StaminaCost = 5,
				HitStun = 0.15,
			},
			{
				AnimationId = "Koei3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 6,
				HitStun = 0.2,
			},
			{
				AnimationId = "Koei4",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 7,
				StaminaCost = 6,
				HitStun = 0.25,
				Knockback = 35,
			},
		},

		M2 = {
			{
				AnimationId = "KoeiHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 12,
				StaminaCost = 11,
				HitStun = 0.4,
				Knockback = 50,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "KoeiIdle",
			Walk = "KoeiWalk",
		},

		Sounds = {
			Swing = "KoeiSwing",
			Hit = "KoeiHit",
		},
	},

	Kendo = {
		DisplayName = "Kendo",
		Category = "Armed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.25,
			FeintCooldown = 3.0,
			HeavyAttackCooldown = 2.5,
			ComboEndlag = 0.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.25,
			FallbackHitEnd = 0.55,
			FallbackLength = 1.3,
		},

		M1 = {
			{
				AnimationId = "Kendo1",
				Hitbox = { Size = Vector3.new(4, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 6,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "Kendo2",
				Hitbox = { Size = Vector3.new(4, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 6,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "Kendo3",
				Hitbox = { Size = Vector3.new(5, 6, 8), Offset = Vector3.new(0, 0, -5) },
				Damage = 8,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "Kendo4",
				Hitbox = { Size = Vector3.new(5, 6, 9), Offset = Vector3.new(0, 0, -5) },
				Damage = 10,
				StaminaCost = 6,
				HitStun = 0.3,
				Knockback = 50,
			},
		},

		M2 = {
			{
				AnimationId = "KendoHeavy",
				Hitbox = { Size = Vector3.new(6, 7, 10), Offset = Vector3.new(0, 0, -6) },
				Damage = 18,
				StaminaCost = 12,
				HitStun = 0.5,
				Knockback = 65,
			},
		},

		Animations = {
			Block = "KendoBlock",
			BlockHit = "KendoBlockHit",
			Idle = "KendoIdle",
			Walk = "KendoWalk",
		},

		Sounds = {
			Swing = "KendoSwing",
			Hit = "KendoHit",
		},
	},

	KungFu = {
		DisplayName = "Kung Fu",
		Category = "Unarmed",

		Balance = {
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

		Timing = {
			Feintable = true,
			FeintEndlag = 0.2,
			FeintCooldown = 2.5,
			HeavyAttackCooldown = 2.0,
			ComboEndlag = 0.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackHitStart = 0.2,
			FallbackHitEnd = 0.5,
			FallbackLength = 1.1,
		},

		M1 = {
			{
				AnimationId = "KungFu1",
				Hitbox = { Size = Vector3.new(3, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "KungFu2",
				Hitbox = { Size = Vector3.new(3, 4, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 4,
				HitStun = 0.2,
			},
			{
				AnimationId = "KungFu3",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 5,
				HitStun = 0.25,
			},
			{
				AnimationId = "KungFu4",
				Hitbox = { Size = Vector3.new(4, 5, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 5,
				HitStun = 0.3,
				Knockback = 45,
			},
		},

		M2 = {
			{
				AnimationId = "KungFuHeavy",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 14,
				StaminaCost = 10,
				HitStun = 0.5,
				Knockback = 60,
			},
		},

		Animations = {
			Block = "Block",
			BlockHit = "BlockHit",
			Idle = "KungFuIdle",
			Walk = "KungFuWalk",
		},

		Sounds = {
			Swing = "KungFuSwing",
			Hit = "KungFuHit",
		},
	},
}

function StyleConfig.Get(StyleName: string): StyleDefinition?
	return Styles[StyleName]
end

function StyleConfig.GetBalance(StyleName: string): BalanceConfig
	local Style = Styles[StyleName]
	if Style and Style.Balance then
		return Style.Balance
	end
	return DEFAULT_BALANCE
end

function StyleConfig.GetTiming(StyleName: string): TimingConfig
	local Style = Styles[StyleName]
	if Style and Style.Timing then
		return Style.Timing
	end
	return DEFAULT_TIMING
end

function StyleConfig.GetAttack(StyleName: string, ActionId: string, Index: number): AttackData?
	local Style = Styles[StyleName]
	if not Style then
		return nil
	end

	local ActionAnimations = Style[ActionId]
	if not ActionAnimations then
		return nil
	end

	local ComboLength = #ActionAnimations
	local WrappedIndex = ((Index - 1) % ComboLength) + 1
	return ActionAnimations[WrappedIndex]
end

function StyleConfig.GetComboLength(StyleName: string, ActionId: string): number
	local Style = Styles[StyleName]
	if not Style then
		return 1
	end

	local ActionAnimations = Style[ActionId]
	if not ActionAnimations then
		return 1
	end

	return #ActionAnimations
end

function StyleConfig.GetAnimation(StyleName: string, AnimationType: string): string?
	local Style = Styles[StyleName]
	if not Style or not Style.Animations then
		return nil
	end
	return Style.Animations[AnimationType]
end

function StyleConfig.GetSound(StyleName: string, SoundType: string): string?
	local Style = Styles[StyleName]
	if not Style or not Style.Sounds then
		return nil
	end
	return Style.Sounds[SoundType]
end

function StyleConfig.GetPassiveMultiplier(MultiplierName: string): number?
	return PASSIVE_MULTIPLIERS[MultiplierName]
end

function StyleConfig.StyleExists(StyleName: string): boolean
	return Styles[StyleName] ~= nil
end

function StyleConfig.GetAllStyleNames(): { string }
	local Names = {}
	for StyleName in Styles do
		table.insert(Names, StyleName)
	end
	return Names
end

return StyleConfig