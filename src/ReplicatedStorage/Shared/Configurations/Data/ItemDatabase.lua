--!strict

local ItemDatabase = {}

export type ItemDefinition = {
	ItemName: string,
	ItemType: string,
	Icon: string,
	Description: string,
	MaxStackSize: number,
	Rarity: number,
	AnimationSet: string?,
	BaseStats: {
		Damage: number?,
		AttackSpeed: number?,
		Range: number?,
		Durability: number?,
		Defense: number?,
		[string]: any,
	}?,
	Metadata: { [string]: any }?,
}

local ITEM_DEFINITIONS: { [string]: ItemDefinition } = {
	["Karate"] = {
		ItemName = "Karate",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "A martial art focused on powerful strikes.",
		MaxStackSize = 1,
		Rarity = 1,
		AnimationSet = "Karate",
		BaseStats = {
			ActionName = "M1",
			FeintEndlag = 0.25,
			FeintCooldown = 3.0,
			ComboEndlag = 0.5,
			Feintable = true,

			FallbackTimings = {
				HitStart = 0.25,
				HitEnd = 0.55,
				Length = 1.25
			},
		},
	},

	["Fists"] = {
		ItemName = "Fists",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "Basic unarmed combat.",
		MaxStackSize = 1,
		Rarity = 1,
		AnimationSet = "Fists",
		BaseStats = {
			ActionName = "M1",
			FeintEndlag = 0.2,
			FeintCooldown = 2.5,
			ComboEndlag = 0.3,
			Feintable = true,

			FallbackTimings = {
				HitStart = 0.2,
				HitEnd = 0.5,
				Length = 1.0
			},
		},
	},

	["MuayThai"] = {
		ItemName = "Muay Thai",
		ItemType = "Style",
		Icon = "rbxassetid://0",
		Description = "The art of eight limbs.",
		MaxStackSize = 1,
		Rarity = 2,
		AnimationSet = "MuayThai",
		BaseStats = {
			ActionName = "M1",
			FeintEndlag = 0.3,
			FeintCooldown = 3.5,
			ComboEndlag = 0.6,
			Feintable = true,

			FallbackTimings = {
				HitStart = 0.3,
				HitEnd = 0.6,
				Length = 1.5
			},
		},
	},

	["ReverseKick"] = {
		ItemName = "Reverse Kick",
		ItemType = "Weapon",
		Icon = "rbxassetid://0",
		Description = "A powerful reverse kick.",
		MaxStackSize = 1,
		Rarity = 1,
		AnimationSet = "ReverseKick",
		BaseStats = {
			Damage = 25,
			Range = 5,
			Power = 15,
			Durability = 100,
			Cooldown = 5,
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

return ItemDatabase