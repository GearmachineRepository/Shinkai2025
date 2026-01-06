--!strict

local ItemDatabase = {}

export type ItemType = "Style" | "Skill" | "Weapon" | "Consumable" | "Material"

export type Modifiers = {
	DamageMultiplier: number?,
	StaminaCostMultiplier: number?,
	RangeMultiplier: number?,
	SpeedMultiplier: number?,
}

export type SkillMetadata = {
	Power: number,
	Range: number,
	Cooldown: number,
	Speed: number,
}

export type WeaponMetadata = {
	Durability: number,
}

export type ItemDefinition = {
	ItemId: string,
	ItemName: string,
	ItemType: ItemType,
	Icon: string,
	Description: string,
	MaxStackSize: number,
	Rarity: number,

	Style: string?,
	Modifiers: Modifiers?,
	Metadata: SkillMetadata | WeaponMetadata | nil,
}

local ITEMS: { [string]: ItemDefinition } = {

	Karate = {
		ItemId = "Karate",
		ItemName = "Karate",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "A martial art focused on powerful strikes.",
		MaxStackSize = 1,
		Rarity = 1,
		Style = "Karate",
	},

	Fists = {
		ItemId = "Fists",
		ItemName = "Fists",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Basic unarmed combat.",
		MaxStackSize = 1,
		Rarity = 1,
		Style = "Fists",
	},

	MuayThai = {
		ItemId = "MuayThai",
		ItemName = "Muay Thai",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The art of eight limbs.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "MuayThai",
	},

	Boxing = {
		ItemId = "Boxing",
		ItemName = "Boxing",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The sweet science of punching.",
		MaxStackSize = 1,
		Rarity = 1,
		Style = "Boxing",
	},

	Judo = {
		ItemId = "Judo",
		ItemName = "Judo",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The gentle way of throws and grappling.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "Judo",
	},

	Wrestling = {
		ItemId = "Wrestling",
		ItemName = "Wrestling",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Heavy grappling that benefits from weight.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "Wrestling",
	},

	Brawl = {
		ItemId = "Brawl",
		ItemName = "Brawl",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Street fighting with raw power.",
		MaxStackSize = 1,
		Rarity = 1,
		Style = "Brawl",
	},

	Taekwondo = {
		ItemId = "Taekwondo",
		ItemName = "Taekwondo",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Korean martial art focused on kicks.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "Taekwondo",
	},

	Kendo = {
		ItemId = "Kendo",
		ItemName = "Kendo",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The way of the sword.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "Kendo",
	},

	KungFu = {
		ItemId = "KungFu",
		ItemName = "Kung Fu",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Traditional Chinese martial arts.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "KungFu",
	},

	Raishin = {
		ItemId = "Raishin",
		ItemName = "Raishin",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Lightning-fast strikes from the Mikazuchi clan.",
		MaxStackSize = 1,
		Rarity = 3,
		Style = "Raishin",
	},

	Kure = {
		ItemId = "Kure",
		ItemName = "Kure",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Assassination techniques of the Kure clan.",
		MaxStackSize = 1,
		Rarity = 3,
		Style = "Kure",
	},

	Niko = {
		ItemId = "Niko",
		ItemName = "Niko",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The four katas of the Niko style.",
		MaxStackSize = 1,
		Rarity = 4,
		Style = "Niko",
	},

	Gaoh = {
		ItemId = "Gaoh",
		ItemName = "Gaoh",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Ancient assassination style of the Gaoh clan.",
		MaxStackSize = 1,
		Rarity = 3,
		Style = "Gaoh",
	},

	Koei = {
		ItemId = "Koei",
		ItemName = "Koei",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The soft style emphasizing joint manipulation.",
		MaxStackSize = 1,
		Rarity = 3,
		Style = "Koei",
	},

	Flashfire = {
		ItemId = "Flashfire",
		ItemName = "Flashfire",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A quick burst of flames that deals rapid damage.",
		MaxStackSize = 1,
		Rarity = 2,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	IronBreaker = {
		ItemId = "IronBreaker",
		ItemName = "Iron Breaker",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A devastating guard-breaking punch.",
		MaxStackSize = 1,
		Rarity = 3,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	DevilLance = {
		ItemId = "DevilLance",
		ItemName = "Devil Lance",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A piercing strike with extended range.",
		MaxStackSize = 1,
		Rarity = 3,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	RakshsasPalm = {
		ItemId = "RakshsasPalm",
		ItemName = "Rakshasa's Palm",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A spiraling palm strike.",
		MaxStackSize = 1,
		Rarity = 4,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	Weeping = {
		ItemId = "Weeping",
		ItemName = "Weeping Willow",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A flowing redirection technique.",
		MaxStackSize = 1,
		Rarity = 3,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	GoddoGuro = {
		ItemId = "GoddoGuro",
		ItemName = "God Glow",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A blinding elbow strike exclusive to Wongsawat clan.",
		MaxStackSize = 1,
		Rarity = 4,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	Zon = {
		ItemId = "Zon",
		ItemName = "Zōn",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A zone-based perception technique exclusive to Imai clan.",
		MaxStackSize = 1,
		Rarity = 4,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	Hachikaiken = {
		ItemId = "Hachikaiken",
		ItemName = "Hachikaiken",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "Wu clan's eight-direction strikes.",
		MaxStackSize = 1,
		Rarity = 4,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	Jusansatsuken = {
		ItemId = "Jusansatsuken",
		ItemName = "Jusansatsuken",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "Wu clan's thirteen killing techniques.",
		MaxStackSize = 1,
		Rarity = 4,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	EarthCrouchingDragon = {
		ItemId = "EarthCrouchingDragon",
		ItemName = "Earth-Crouching Dragon",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "Gaoh style's signature low strike.",
		MaxStackSize = 1,
		Rarity = 3,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	RaishinKick = {
		ItemId = "RaishinKick",
		ItemName = "Raishin Kick",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "Lightning-fast consecutive kicks.",
		MaxStackSize = 1,
		Rarity = 3,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	LegThrust = {
		ItemId = "LegThrust",
		ItemName = "Leg Thrust",
		ItemType = "Skill",
		Icon = "rbxassetid://0",
		Description = "A powerful kick with extended range.",
		MaxStackSize = 1,
		Rarity = 2,
		Metadata = {
			Power = 5,
			Range = 5,
			Cooldown = 5,
			Speed = 5,
		},
	},

	IronKnuckles = {
		ItemId = "IronKnuckles",
		ItemName = "Iron Knuckles",
		ItemType = "Weapon",
		Icon = "rbxassetid://0",
		Description = "Heavy knuckles that increase punch damage.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "Fists",
		Modifiers = {
			DamageMultiplier = 1.25,
		},
		Metadata = {
			Durability = 100,
		},
	},

	TrainingGloves = {
		ItemId = "TrainingGloves",
		ItemName = "Training Gloves",
		ItemType = "Weapon",
		Icon = "rbxassetid://0",
		Description = "Light gloves that reduce stamina cost.",
		MaxStackSize = 1,
		Rarity = 1,
		Style = "Fists",
		Modifiers = {
			StaminaCostMultiplier = 0.8,
		},
		Metadata = {
			Durability = 50,
		},
	},

	SpeedWraps = {
		ItemId = "SpeedWraps",
		ItemName = "Speed Wraps",
		ItemType = "Weapon",
		Icon = "rbxassetid://0",
		Description = "Hand wraps that increase attack speed.",
		MaxStackSize = 1,
		Rarity = 2,
		Style = "Boxing",
		Modifiers = {
			SpeedMultiplier = 1.15,
			DamageMultiplier = 0.9,
		},
		Metadata = {
			Durability = 75,
		},
	},
}

function ItemDatabase.GetItem(ItemId: string): ItemDefinition?
	return ITEMS[ItemId]
end

function ItemDatabase.GetAllItems(): { ItemDefinition }
	local AllItems: { ItemDefinition } = {}
	for _, ItemDef in ITEMS do
		table.insert(AllItems, ItemDef)
	end
	return AllItems
end

function ItemDatabase.GetItemsByType(ItemType: ItemType): { ItemDefinition }
	local FilteredItems: { ItemDefinition } = {}
	for _, ItemDef in ITEMS do
		if ItemDef.ItemType == ItemType then
			table.insert(FilteredItems, ItemDef)
		end
	end
	return FilteredItems
end

function ItemDatabase.ItemExists(ItemId: string): boolean
	return ITEMS[ItemId] ~= nil
end

function ItemDatabase.GetStyle(ItemId: string): string?
	local Item = ITEMS[ItemId]
	if Item then
		return Item.Style
	end
	return nil
end

function ItemDatabase.HasMetadata(ItemId: string): boolean
	local Item = ITEMS[ItemId]
	return Item ~= nil and Item.Metadata ~= nil
end

function ItemDatabase.GetMetadata(ItemId: string): (SkillMetadata | WeaponMetadata)?
	local Item = ITEMS[ItemId]
	if Item then
		return Item.Metadata
	end
	return nil
end

function ItemDatabase.GetModifiers(ItemId: string): Modifiers?
	local Item = ITEMS[ItemId]
	if Item then
		return Item.Modifiers
	end
	return nil
end

function ItemDatabase.IsSkill(ItemId: string): boolean
	local Item = ITEMS[ItemId]
	return Item ~= nil and Item.ItemType == "Skill"
end

function ItemDatabase.IsStyle(ItemId: string): boolean
	local Item = ITEMS[ItemId]
	return Item ~= nil and Item.ItemType == "Style"
end

return ItemDatabase