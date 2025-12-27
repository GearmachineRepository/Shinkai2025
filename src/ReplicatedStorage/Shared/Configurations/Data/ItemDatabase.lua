--!strict

local ItemDatabase = {}

export type ItemDefinition = {
	ItemId: string,
	ItemName: string,
	ItemType: string,
	Icon: string,
	Description: string,
	MaxStackSize: number,
	Rarity: string,
	AnimationSet: string?,
	BaseStats: {
		Damage: number?,
		AttackSpeed: number?,
		Range: number?,
		Durability: number?,
		Defense: number?,
	}?,
	Metadata: { [string]: any }?,
}

local ITEM_DEFINITIONS: { [string]: ItemDefinition } = {
	["karate_style"] = {
		ItemId = "karate_style",
		ItemName = "Karate",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "A martial art focused on powerful strikes",
		MaxStackSize = 1,
		Rarity = "Common",
		AnimationSet = "Karate",
		BaseStats = {
			Damage = 8,
			AttackSpeed = 1.0,
		},
	},

	["wooden_sword"] = {
		ItemId = "wooden_sword",
		ItemName = "Wooden Sword",
		ItemType = "Weapon",
		Icon = "rbxassetid://123456789",
		Description = "A basic wooden sword for beginners",
		MaxStackSize = 1,
		Rarity = "Common",
		AnimationSet = "Fists",
		BaseStats = {
			Damage = 10,
			AttackSpeed = 1.0,
			Range = 5,
			Durability = 100,
		},
	},

	["iron_sword"] = {
		ItemId = "iron_sword",
		ItemName = "Iron Sword",
		ItemType = "Weapon",
		Icon = "rbxassetid://123456790",
		Description = "A sturdy iron blade",
		MaxStackSize = 1,
		Rarity = "Uncommon",
		AnimationSet = "Fists",
		BaseStats = {
			Damage = 20,
			AttackSpeed = 0.9,
			Range = 5,
			Durability = 250,
		},
	},

	["steel_katana"] = {
		ItemId = "steel_katana",
		ItemName = "Steel Katana",
		ItemType = "Weapon",
		Icon = "rbxassetid://123456791",
		Description = "A swift and deadly katana",
		MaxStackSize = 1,
		Rarity = "Rare",
		AnimationSet = "Fists",
		BaseStats = {
			Damage = 35,
			AttackSpeed = 1.3,
			Range = 6,
			Durability = 500,
		},
	},

	["wooden_shield"] = {
		ItemId = "wooden_shield",
		ItemName = "Wooden Shield",
		ItemType = "Shield",
		Icon = "rbxassetid://123456792",
		Description = "Basic protection",
		MaxStackSize = 1,
		Rarity = "Common",
		BaseStats = {
			Defense = 5,
			Durability = 150,
		},
	},

	["health_potion"] = {
		ItemId = "health_potion",
		ItemName = "Health Potion",
		ItemType = "Consumable",
		Icon = "rbxassetid://123456793",
		Description = "Restores 50 HP",
		MaxStackSize = 10,
		Rarity = "Common",
		Metadata = {
			HealAmount = 50,
			Cooldown = 5,
		},
	},

	["training_gloves"] = {
		ItemId = "training_gloves",
		ItemName = "Training Gloves",
		ItemType = "Weapon",
		Icon = "rbxassetid://123456794",
		Description = "For hand-to-hand combat training",
		MaxStackSize = 1,
		Rarity = "Common",
		AnimationSet = "Fists",
		BaseStats = {
			Damage = 8,
			AttackSpeed = 1.5,
			Range = 3,
			Durability = 200,
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

function ItemDatabase.GetAnimationSet(ItemId: string): string?
	local ItemDef = ITEM_DEFINITIONS[ItemId]
	if not ItemDef then
		return nil
	end
	return ItemDef.AnimationSet
end

function ItemDatabase.RegisterItem(ItemDefinition: ItemDefinition)
	if ITEM_DEFINITIONS[ItemDefinition.ItemId] then
		warn("ItemDatabase: Item already exists:", ItemDefinition.ItemId)
		return false
	end

	ITEM_DEFINITIONS[ItemDefinition.ItemId] = ItemDefinition
	return true
end

return ItemDatabase