--!strict

local AnimationSets = {}

export type HitboxData = {
	Size: Vector3,
	Offset: Vector3,
}

export type AttackData = {
	AnimationId: string,
	Hitbox: HitboxData,
	Damage: number,
	StaminaCost: number,
	HitStun: number,
}

export type FallbackTimings = {
	HitStart: number,
	HitEnd: number,
	Length: number,
}

export type AnimationSetMetadata = {
	Feintable: boolean,
	FeintEndlag: number,
	FeintCooldown: number,
	HeavyAttackCooldown: number,
	ComboEndlag: number,
	ComboResetTime: number,
	StaminaCostHitReduction: number,
	FallbackTimings: FallbackTimings,
}

export type AnimationSet = {
	DisplayName: string,
	Category: string,
	Metadata: AnimationSetMetadata,
	M1: { AttackData },
	M2: { AttackData? }?,
	Block: { AnimationId: string }?,
	BlockHit: { AnimationId: string }?,
	Sounds: {
		Swing: string?,
		Hit: string?,
	}?,
}

local DEFAULT_METADATA: AnimationSetMetadata = {
	Feintable = true,
	FeintEndlag = 0.25,
	FeintCooldown = 3.0,
	HeavyAttackCooldown = 2.0,
	ComboEndlag = 0.5,
	ComboResetTime = 2.0,
	StaminaCostHitReduction = 0.15,
	FallbackTimings = {
		HitStart = 0.25,
		HitEnd = 0.55,
		Length = 1.25,
	},
}

local Sets: { [string]: AnimationSet } = {
	Karate = {
		DisplayName = "Karate",
		Category = "Unarmed",

		Metadata = {
			Feintable = true,
			FeintEndlag = 0.25,
			FeintCooldown = 0.5,
			HeavyAttackCooldown = 4.0,
			ComboEndlag = 0.5,
			ComboResetTime = 2.0,
			StaminaCostHitReduction = 0.15,
			FallbackTimings = {
				HitStart = 0.25,
				HitEnd = 0.55,
				Length = 1.25,
			},
		},

		M1 = {
			[1] = {
				AnimationId = "Karate1",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 4,
				HitStun = 0.35,
			},
			[2] = {
				AnimationId = "Karate2",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 4,
				HitStun = 0.35,
			},
			[3] = {
				AnimationId = "Karate3",
				Hitbox = { Size = Vector3.new(5, 4, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 10,
				StaminaCost = 5,
				HitStun = 0.45,
			},
			[4] = {
				AnimationId = "Karate4",
				Hitbox = { Size = Vector3.new(6, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 14,
				StaminaCost = 6,
				HitStun = 0.45,
			},
		},

		M2 = {
			[1] = {
				AnimationId = "KarateHeavy",
				Hitbox = { Size = Vector3.new(6, 5, 8), Offset = Vector3.new(0, 0, -5) },
				Damage = 20,
				StaminaCost = 12,
				HitStun = 0.5,
			}
		},

		Block = { AnimationId = "Block" },
		BlockHit = { AnimationId = "BlockHit" },

		Sounds = {
			Swing = "KarateSwing",
			Hit = "KarateHit",
		},
	},

	Fists = {
		DisplayName = "Fists",
		Category = "Unarmed",

		Metadata = {
			Feintable = true,
			FeintEndlag = 0.2,
			FeintCooldown = 2.5,
			HeavyAttackCooldown = 2.0,
			ComboEndlag = 0.3,
			ComboResetTime = 1.5,
			StaminaCostHitReduction = 0.15,
			FallbackTimings = {
				HitStart = 0.2,
				HitEnd = 0.5,
				Length = 1.0,
			},
		},

		M1 = {
			[1] = {
				AnimationId = "rbxassetid://120810578835776",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 3,
				HitStun = 0.2,
			},
			[2] = {
				AnimationId = "rbxassetid://135298421079091",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 3,
				HitStun = 0.2,
			},
			[3] = {
				AnimationId = "rbxassetid://90246825026625",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 4,
				HitStun = 0.25,
			},
			[4] = {
				AnimationId = "rbxassetid://71745443772185",
				Hitbox = { Size = Vector3.new(5, 4, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 8,
				StaminaCost = 5,
				HitStun = 0.3,
			},
		},

		M2 = {
			[1] = {
				AnimationId = "rbxassetid://181818",
				Hitbox = { Size = Vector3.new(5, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 15,
				StaminaCost = 10,
				HitStun = 0.45,
			}
		},

		Block = { AnimationId = "Block" },

		Sounds = {
			Swing = "FistSwing",
			Hit = "FistHit",
		},
	},

	MuayThai = {
		DisplayName = "Muay Thai",
		Category = "Unarmed",

		Metadata = {
			Feintable = true,
			FeintEndlag = 0.3,
			FeintCooldown = 3.5,
			HeavyAttackCooldown = 2.5,
			ComboEndlag = 0.6,
			ComboResetTime = 2.5,
			StaminaCostHitReduction = 0.15,
			FallbackTimings = {
				HitStart = 0.3,
				HitEnd = 0.6,
				Length = 1.5,
			},
		},

		M1 = {
			[1] = {
				AnimationId = "MuayThai1",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 10,
				StaminaCost = 5,
				HitStun = 0.35,
			},
			[2] = {
				AnimationId = "MuayThai2",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 10,
				StaminaCost = 5,
				HitStun = 0.35,
			},
			[3] = {
				AnimationId = "MuayThai3",
				Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 12,
				StaminaCost = 6,
				HitStun = 0.4,
			},
			[4] = {
				AnimationId = "MuayThai4",
				Hitbox = { Size = Vector3.new(6, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 16,
				StaminaCost = 7,
				HitStun = 0.5,
			},
		},

		M2 = {
			[1] = {
				AnimationId = "MuayThaiHeavy",
				Hitbox = { Size = Vector3.new(7, 6, 8), Offset = Vector3.new(0, 0, -5) },
				Damage = 25,
				StaminaCost = 14,
				HitStun = 0.6,
			}
		},

		Block = { AnimationId = "Block" },

		Sounds = {
			Swing = "MuayThaiSwing",
			Hit = "MuayThaiHit",
		},
	},
}

function AnimationSets.Get(SetName: string): AnimationSet?
	return Sets[SetName]
end

function AnimationSets.GetMetadata(SetName: string): AnimationSetMetadata
	local Set = Sets[SetName]
	if Set and Set.Metadata then
		return Set.Metadata
	end
	return DEFAULT_METADATA
end

function AnimationSets.GetAttack(SetName: string, ActionId: string, Index: number): AttackData?
	local Set = Sets[SetName]
	if not Set then
		return nil
	end

	local ActionAnimations = Set[ActionId]
	if not ActionAnimations then
		return nil
	end

	local ComboLength = #ActionAnimations
	local WrappedIndex = ((Index - 1) % ComboLength) + 1
	return ActionAnimations[WrappedIndex]
end

function AnimationSets.GetComboLength(SetName: string, ActionId: string): number
	local Set = Sets[SetName]
	if not Set then
		return 1
	end

	local ActionAnimations = Set[ActionId]
	if not ActionAnimations then
		return 1
	end

	return #ActionAnimations
end

function AnimationSets.GetSound(SetName: string, SoundType: string): string?
	local Set = Sets[SetName]
	if not Set or not Set.Sounds then
		return nil
	end
	return Set.Sounds[SoundType]
end

function AnimationSets.GetBlockAnimation(SetName: string): string?
	local Set = Sets[SetName]
	if not Set or not Set.Block then
		return nil
	end
	return Set.Block.AnimationId
end

return AnimationSets