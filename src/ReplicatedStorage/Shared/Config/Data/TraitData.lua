--!strict

local TraitRarity = {
	UNCOMMON = "Uncommon",
	RARE = "Rare",
	UNIQUE = "Unique",
	MYTHICAL = "Mythical",
}

local TraitDefinitions = {
	Cowardly = {
		Name = "Cowardly",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "At the start of combat, receive a 10% run buff for 5 seconds",
		Hooks = {"CowardlyCombatStart"},
	},

	WeakWilled = {
		Name = "Weak Willed",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Debuffs from skills last 2% longer",
		Modifiers = {
			DebuffDurationMultiplier = 1.02,
		},
	},

	Forceful = {
		Name = "Forceful",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Guard breaks last for 1.5% longer",
		Modifiers = {
			GuardBreakDurationMultiplier = 1.015,
		},
	},

	Resourceful = {
		Name = "Resourceful",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Mode lasts for 5% longer",
		Modifiers = {
			ModeDurationMultiplier = 1.05,
		},
	},

	Careful = {
		Name = "Careful",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Increased parry / PB window",
		Modifiers = {
			ParryWindowBonus = 0.05,
			PerfectBlockWindowBonus = 0.05,
		},
	},

	Disciplined = {
		Name = "Disciplined",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Increases fatigue cap from 100% to 120%",
		Modifiers = {
			MaxFatigueMultiplier = 1.2,
		},
	},

	Loud = {
		Name = "Loud",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Player yells every 10th attack",
		Hooks = {"LoudYell"},
	},

	Nasty = {
		Name = "Nasty",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Green foul odor lingers around the player (flies included)",
		Hooks = {"NastyEffect"},
	},

	Charismatic = {
		Name = "Charismatic",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "General prices are reduced by 10%",
		Modifiers = {
			PriceMultiplier = 0.9,
		},
	},

	Hopeful = {
		Name = "Hopeful",
		Rarity = TraitRarity.UNCOMMON,
		RarityWeight = 75,
		Description = "Damage increases the lower you get, caps at 10%",
		Hooks = {"HopefulDamageBoost"},
	},

	Efficient = {
		Name = "Efficient",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "10% lower cooldown on moves, but with 5% less damage",
		Modifiers = {
			CooldownMultiplier = 0.9,
			DamageMultiplier = 0.95,
		},
	},

	Observant = {
		Name = "Observant",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "10% increase in counter frames",
		Modifiers = {
			CounterFrameMultiplier = 1.1,
		},
	},

	Lucky = {
		Name = "Lucky",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "25% chance to take 5% less damage from attacks. No cooldown",
		Hooks = {"LuckyDamageReduction"},
	},

	Lazy = {
		Name = "Lazy",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "Attacks take 10% less stamina but do 5% less damage",
		Modifiers = {
			StaminaCostMultiplier = 0.9,
			DamageMultiplier = 0.95,
		},
	},

	Emotional = {
		Name = "Emotional",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "After losing 20% of your total hp, gain a 10% damage buff for 7s and start crying. 30 second cd",
		Hooks = {"EmotionalBuff"},
	},

	Deceitful = {
		Name = "Deceitful",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "Every 3rd dash, player spawns an after image dashing the opposite direction as them. Despawns as soon as the dash ends.",
		Hooks = {"DeceitfulAfterimage"},
	},

	Brave = {
		Name = "Brave",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "When being hit from multiple people, take 35% less damage and stun",
		Hooks = {"BraveMultiHitReduction"},
	},

	Versatile = {
		Name = "Versatile",
		Rarity = TraitRarity.RARE,
		RarityWeight = 22.999,
		Description = "Gain an extra skill slot, you can now use 7 skills",
		Modifiers = {
			MaxSkillSlots = 7,
		},
	},

	Unpredictable = {
		Name = "Unpredictable",
		Rarity = TraitRarity.UNIQUE,
		RarityWeight = 2,
		Description = "Allows the player to feint two skills before going on a 30 second CD",
		Hooks = {"UnpredictableFeint"},
	},

	Arrogant = {
		Name = "Arrogant",
		Rarity = TraitRarity.UNIQUE,
		RarityWeight = 2,
		Description = "Decreases the down threshold of every down-stating move by 10%",
		Modifiers = {
			DownThresholdReduction = 10,
		},
	},

	Patient = {
		Name = "Patient",
		Rarity = TraitRarity.UNIQUE,
		RarityWeight = 2,
		Description = "For every second that the player isn't attacking, running, jogging, or dashing, their next attack's damage increases by 1%. Caps at 8% and resets after landing an attack",
		Hooks = {"PatientDamageStack"},
	},

	Impatient = {
		Name = "Impatient",
		Rarity = TraitRarity.UNIQUE,
		RarityWeight = 2,
		Description = "After landing 4 skills, global cd is removed for the next skill",
		Hooks = {"ImpatientCooldownReset"},
	},

	Cruel = {
		Name = "Cruel",
		Rarity = TraitRarity.UNIQUE,
		RarityWeight = 2,
		Description = "All attacks have a 15% chance to apply bleed, 5% for multi-hit moves. 20 second cd.",
		Hooks = {"CruelBleedChance"},
	},

	Insane = {
		Name = "Insane",
		Rarity = TraitRarity.MYTHICAL,
		RarityWeight = 0.001,
		Description = "After getting knocked, the player starts laughing and geeking out on the floor. The player goes berserk and goes after the player who knocked them. After 10 seconds, player regains control, along with 5% hp (15 minute cd)",
		Hooks = {"InsaneBerserk"},
	},

	SecondHand = {
		Name = "Second Hand",
		Rarity = TraitRarity.MYTHICAL,
		RarityWeight = 0.001,
		Description = "After the player is attacked 2 times by the same skill, the player gains the ability to use it (bypasses pure and clan locked skills, 40 second CD)",
		Hooks = {"SecondHandSkillCopy"},
	},
}

return {
	Rarity = TraitRarity,
	Definitions = TraitDefinitions,
}