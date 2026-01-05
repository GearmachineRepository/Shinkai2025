--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ClanData = require(Shared.Config.Data.ClanData)

local ClanSystem = {}

function ClanSystem.GetWeightedRandomClan(): string
	local TotalWeight = 0
	local WeightedClans = {}

	for ClanName, ClanDef in ClanData.Definitions do
		TotalWeight += ClanDef.RarityWeight
		table.insert(WeightedClans, {
			Clan = ClanName,
			Weight = ClanDef.RarityWeight,
		})
	end

	local RandomValue = math.random() * TotalWeight
	local CurrentWeight = 0

	for _, Entry in WeightedClans do
		CurrentWeight += Entry.Weight
		if RandomValue <= CurrentWeight then
			return Entry.Clan
		end
	end

	return ClanData.Types.BROWN
end

function ClanSystem.GetClanDefinition(ClanName: string)
	return ClanData.Definitions[ClanName]
end

function ClanSystem.ApplyClanBonuses(PlayerData: any, ClanName: string)
	local ClanDef = ClanSystem.GetClanDefinition(ClanName)
	if not ClanDef then
		warn("Unknown clan:", ClanName)
		return
	end

	for StatName, BonusValue in ClanDef.StatBonuses do
		if PlayerData.Stats[StatName] then
			PlayerData.Stats[StatName] += BonusValue
		end
	end

	PlayerData.Clan = {
		ClanName = ClanName,
		ClanRarity = ClanDef.RarityWeight,
	}
end

function ClanSystem.GetUnlockedStyles(ClanName: string): {string}
	local ClanDef = ClanSystem.GetClanDefinition(ClanName)
	if not ClanDef then
		return {}
	end

	return ClanDef.UnlockedStyles or {}
end

function ClanSystem.GetUnlockedMode(ClanName: string): string?
	local ClanDef = ClanSystem.GetClanDefinition(ClanName)
	if not ClanDef then
		return nil
	end

	return ClanDef.UnlockedMode
end

function ClanSystem.GetUnlockedSkills(ClanName: string): {string}
	local ClanDef = ClanSystem.GetClanDefinition(ClanName)
	if not ClanDef then
		return {}
	end

	return ClanDef.UnlockedSkills or {}
end

function ClanSystem.GetClanHooks(ClanName: string): {string}
	local ClanDef = ClanSystem.GetClanDefinition(ClanName)
	if not ClanDef then
		return {}
	end

	return ClanDef.Hooks or {}
end

return ClanSystem