--!strict

local ItemDatabase = {}

export type StatModifiers = {
	DamageMultiplier: number?,
	StaminaCostMultiplier: number?,
	RangeMultiplier: number?,
	[string]: any,
}

export type ItemDefinition = {
	ItemId: string,
	ItemName: string,
	ItemType: string,
	Icon: string,
	Description: string,
	MaxStackSize: number,
	Rarity: number,
	AnimationSet: string,
	StatModifiers: StatModifiers?,
	Metadata: { [string]: any }?,
}

local ITEM_DEFINITIONS: { [string]: ItemDefinition } = {
	["Karate"] = {
		ItemId = "Karate",
		ItemName = "Karate",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "A martial art focused on powerful strikes.",
		MaxStackSize = 1,
		Rarity = 1,
		AnimationSet = "Karate",
	},

	["Fists"] = {
		ItemId = "Fists",
		ItemName = "Fists",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Basic unarmed combat.",
		MaxStackSize = 1,
		Rarity = 1,
		AnimationSet = "Fists",
	},

	["MuayThai"] = {
		ItemId = "MuayThai",
		ItemName = "Muay Thai",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The art of eight limbs.",
		MaxStackSize = 1,
		Rarity = 2,
		AnimationSet = "MuayThai",
	},

	["IronKnuckles"] = {
		ItemId = "IronKnuckles",
		ItemName = "Iron Knuckles",
		ItemType = "Weapon",
		Icon = "rbxassetid://0",
		Description = "Heavy knuckles that increase punch damage.",
		MaxStackSize = 1,
		Rarity = 2,
		AnimationSet = "Fists",
		StatModifiers = {
			DamageMultiplier = 1.25,
		},
		Metadata = {
			Durability = 100,
		},
	},

	["TrainingGloves"] = {
		ItemId = "TrainingGloves",
		ItemName = "Training Gloves",
		ItemType = "Weapon",
		Icon = "rbxassetid://0",
		Description = "Light gloves that reduce stamina cost.",
		MaxStackSize = 1,
		Rarity = 1,
		AnimationSet = "Fists",
		StatModifiers = {
			StaminaCostMultiplier = 0.8,
		},
		Metadata = {
			Durability = 50,
		},
	},
}

function ItemDatabase.GetItem(ItemId: string): ItemDefinition?
	return ITEM_DEFINITIONS[ItemId]
end

function ItemDatabase.GetAllItems(): { ItemDefinition }
	local AllItems: { ItemDefinition } = {}
	for _, ItemDef in ITEM_DEFINITIONS do
		table.insert(AllItems, ItemDef)
	end
	return AllItems
end

function ItemDatabase.GetItemsByType(ItemType: string): { ItemDefinition }
	local FilteredItems: { ItemDefinition } = {}
	for _, ItemDef in ITEM_DEFINITIONS do
		if ItemDef.ItemType == ItemType then
			table.insert(FilteredItems, ItemDef)
		end
	end
	return FilteredItems
end

function ItemDatabase.ItemExists(ItemId: string): boolean
	return ITEM_DEFINITIONS[ItemId] ~= nil
end

return ItemDatabase