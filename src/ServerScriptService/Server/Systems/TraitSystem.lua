--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local TraitData = require(Shared.Configurations.Data.TraitData)

local TraitSystem = {}

local MAX_TRAITS = 2

function TraitSystem.GetWeightedRandomTrait(): string
	local TotalWeight = 0
	local WeightedTraits = {}

	for TraitName, TraitDef in TraitData.Definitions do
		TotalWeight += TraitDef.RarityWeight
		table.insert(WeightedTraits, {
			Trait = TraitName,
			Weight = TraitDef.RarityWeight,
		})
	end

	local RandomValue = math.random() * TotalWeight
	local CurrentWeight = 0

	for _, Entry in WeightedTraits do
		CurrentWeight += Entry.Weight
		if RandomValue <= CurrentWeight then
			return Entry.Trait
		end
	end

	local FirstTrait = next(TraitData.Definitions)
	return FirstTrait
end

function TraitSystem.GetTraitDefinition(TraitName: string)
	return TraitData.Definitions[TraitName]
end

function TraitSystem.RollSingleTrait(PlayerData: any, SlotIndex: number): string
	if SlotIndex < 1 or SlotIndex > MAX_TRAITS then
		warn("Invalid trait slot:", SlotIndex)
		return ""
	end

	local NewTrait = TraitSystem.GetWeightedRandomTrait()
	PlayerData.Traits[SlotIndex] = NewTrait

	return NewTrait
end

function TraitSystem.RollBothTraits(PlayerData: any): {string}
	local Trait1 = TraitSystem.GetWeightedRandomTrait()
	local Trait2 = TraitSystem.GetWeightedRandomTrait()

	while Trait1 == Trait2 do
		Trait2 = TraitSystem.GetWeightedRandomTrait()
	end

	PlayerData.Traits[1] = Trait1
	PlayerData.Traits[2] = Trait2

	return {Trait1, Trait2}
end

function TraitSystem.GetTraitModifiers(TraitName: string)
	local TraitDef = TraitSystem.GetTraitDefinition(TraitName)
	if not TraitDef then
		return {}
	end

	return TraitDef.Modifiers or {}
end

function TraitSystem.GetTraitHooks(TraitName: string): {string}
	local TraitDef = TraitSystem.GetTraitDefinition(TraitName)
	if not TraitDef then
		return {}
	end

	return TraitDef.Hooks or {}
end

function TraitSystem.GetAllPlayerTraitHooks(PlayerData: any): {string}
	local AllHooks = {}

	for _, TraitName in PlayerData.Traits do
		if TraitName and TraitName ~= "" then
			local Hooks = TraitSystem.GetTraitHooks(TraitName)
			for _, Hook in Hooks do
				table.insert(AllHooks, Hook)
			end
		end
	end

	return AllHooks
end

return TraitSystem