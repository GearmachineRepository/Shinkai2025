--!strict

local AnimationSet = {}

export type HitboxData = {
	Size: Vector3,
	Offset: Vector3,
}

export type AttackData = {
	AnimationId: string,
	Hitbox: HitboxData,
	Damage: number,
	StaminaCost: number,
}

export type AnimationSet = {
	DisplayName: string,
	Category: string,

	Attacks: { AttackData },

	HeavyAttack: AttackData?,

	Block: { AnimationId: string }?,
	BlockHit: { AnimationId: string }?,

	Sounds: {
		Swing: string?,
		Hit: string?,
	}?,
}

local AnimationSets: { [string]: AnimationSet } = {
	Karate = {
		DisplayName = "Karate",
		Category = "Unarmed",

		Attacks = {
			[1] = {
				AnimationId = "Karate1",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 4,
			},
			[2] = {
				AnimationId = "Karate2",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 8,
				StaminaCost = 4,
			},
			[3] = {
				AnimationId = "Karate3",
				Hitbox = { Size = Vector3.new(5, 4, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 10,
				StaminaCost = 5,
			},
			[4] = {
				AnimationId = "Karate4",
				Hitbox = { Size = Vector3.new(6, 5, 7), Offset = Vector3.new(0, 0, -4) },
				Damage = 14,
				StaminaCost = 6,
			},
		},

		HeavyAttack = {
			AnimationId = "KarateHeavy",
			Hitbox = { Size = Vector3.new(6, 5, 8), Offset = Vector3.new(0, 0, -5) },
			Damage = 20,
			StaminaCost = 12,
		},

		Block = { AnimationId = "Blocking" },
		BlockHit = { AnimationId = "BlockHit" },

		Sounds = {
			Swing = "KarateSwing",
			Hit = "KarateHit",
		},
	},

	Fists = {
		DisplayName = "Fists",
		Category = "Unarmed",

		Attacks = {
			[1] = {
				AnimationId = "rbxassetid://120810578835776",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 3,
			},
			[2] = {
				AnimationId = "rbxassetid://135298421079091",
				Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },
				Damage = 5,
				StaminaCost = 3,
			},
			[3] = {
				AnimationId = "rbxassetid://90246825026625",
				Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },
				Damage = 6,
				StaminaCost = 4,
			},
			[4] = {
				AnimationId = "rbxassetid://71745443772185",
				Hitbox = { Size = Vector3.new(5, 4, 6), Offset = Vector3.new(0, 0, -4) },
				Damage = 8,
				StaminaCost = 5,
			},
		},

		HeavyAttack = {
			AnimationId = "rbxassetid://181818",
			Hitbox = { Size = Vector3.new(5, 5, 7), Offset = Vector3.new(0, 0, -4) },
			Damage = 15,
			StaminaCost = 10,
		},

		Block = { AnimationId = "rbxassetid://191919" },

		Sounds = {
			Swing = "FistSwing",
			Hit = "FistHit",
		},
	},
}

function AnimationSet.Get(SetName: string): AnimationSet?
	return AnimationSets[SetName]
end

function AnimationSet.GetAttack(SetName: string, Index: number): AttackData?
	local Set = AnimationSets[SetName]
	if not Set then
		return nil
	end

	local ComboLength = #Set.Attacks
	local WrappedIndex = ((Index - 1) % ComboLength) + 1
	return Set.Attacks[WrappedIndex]
end

function AnimationSet.GetHeavyAttack(SetName: string): AttackData?
	local Set = AnimationSets[SetName]
	if not Set then
		return nil
	end
	return Set.HeavyAttack
end

function AnimationSet.GetComboLength(SetName: string): number
	local Set = AnimationSets[SetName]
	if not Set then
		return 1
	end
	return #Set.Attacks
end

function AnimationSet.GetSound(SetName: string, SoundType: string): string?
	local Set = AnimationSets[SetName]
	if not Set or not Set.Sounds then
		return nil
	end
	return Set.Sounds[SoundType]
end

function AnimationSet.GetBlockAnimation(SetName: string): string?
	local Set = AnimationSets[SetName]
	if not Set or not Set.Block then
		return nil
	end
	return Set.Block.AnimationId
end

return AnimationSet