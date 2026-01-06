--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)

local StatSystem = {}

type StarTier = {
	Min: number,
	Max: number,
	Name: string,
	Color: { R: number, G: number, B: number }
}

function StatSystem.CalculateStatValue(BaseStat: number, AllocatedStars: number, StatType: string): number
	local BonusPerStar = ProgressionBalance.StarBonuses[StatType] or 0
	return BaseStat + (AllocatedStars * BonusPerStar)
end

function StatSystem.GetXPThresholdForNextPoint(StatType: string, TotalPointsEarned: number): number
	local BaseThreshold = ProgressionBalance.XPThresholds[StatType]
	local TierIncrement = ProgressionBalance.XPTierIncrement[StatType]
	local TierSize = ProgressionBalance.XPTierSize

	if not BaseThreshold or not TierIncrement or not TierSize then
		return 0
	end

	local TierIndex = math.floor(TotalPointsEarned / TierSize)
	return BaseThreshold + (TierIndex * TierIncrement)
end

function StatSystem.GetTotalPointsEarned(PlayerData: any, StatType: string): number
	local Stars = PlayerData.Stats[StatType .. "_Stars"] or 0
	local Points = PlayerData.Stats[StatType .. "_Points"] or 0
	return Stars + Points
end

function StatSystem.ProcessXPGain(PlayerData: any, StatType: string): number
	local CurrentXP = PlayerData.Stats[StatType .. "_XP"] or 0
	local TotalPointsEarned = StatSystem.GetTotalPointsEarned(PlayerData, StatType)
	local Threshold = StatSystem.GetXPThresholdForNextPoint(StatType, TotalPointsEarned)

	local PointsAwarded = 0

	while CurrentXP >= Threshold and Threshold > 0 do
		CurrentXP = CurrentXP - Threshold
		PlayerData.Stats[StatType .. "_Points"] = (PlayerData.Stats[StatType .. "_Points"] or 0) + 1
		PointsAwarded += 1

		TotalPointsEarned = StatSystem.GetTotalPointsEarned(PlayerData, StatType)
		Threshold = StatSystem.GetXPThresholdForNextPoint(StatType, TotalPointsEarned)
	end

	PlayerData.Stats[StatType .. "_XP"] = CurrentXP

	return PointsAwarded
end

function StatSystem.CanAllocateStar(PlayerData: any, StatType: string): (boolean, string?)
	local CurrentStars = PlayerData.Stats[StatType .. "_Stars"] or 0
	local AvailablePoints = PlayerData.Stats[StatType .. "_Points"] or 0

	if CurrentStars >= ProgressionBalance.Caps.MaxStarsPerStat then
		return false, "Stat already at maximum (" .. ProgressionBalance.Caps.MaxStarsPerStat .. " stars)"
	end

	local TotalStars = StatSystem.GetTotalAllocatedStars(PlayerData)
	if TotalStars >= ProgressionBalance.Caps.TotalSoftCapStars then
		return false, "Reached total star cap (" .. ProgressionBalance.Caps.TotalSoftCapStars .. " stars)"
	end

	if AvailablePoints < ProgressionBalance.Caps.PointsPerStar then
		return false, "Need " .. ProgressionBalance.Caps.PointsPerStar .. " points to allocate a star"
	end

	return true
end

function StatSystem.AllocateStar(PlayerData: any, StatType: string): (boolean, string?)
	local CanAllocate, ErrorMessage = StatSystem.CanAllocateStar(PlayerData, StatType)
	if not CanAllocate then
		return false, ErrorMessage
	end

	PlayerData.Stats[StatType .. "_Stars"] += 1
	PlayerData.Stats[StatType .. "_Points"] -= ProgressionBalance.Caps.PointsPerStar

	return true
end

function StatSystem.GetTotalAllocatedStars(PlayerData: any): number
	local Total = 0

	for StatType: any, _ in ProgressionBalance.StarBonuses do
		Total += PlayerData.Stats[StatType .. "_Stars"] or 0
	end

	return Total
end

function StatSystem.GetStarTier(TotalStars: number): StarTier
	for _, Tier in pairs(ProgressionBalance.StarTiers) do
		if TotalStars >= Tier.Min and TotalStars <= Tier.Max then
			return Tier
		end
	end

	return ProgressionBalance.StarTiers[1]
end

function StatSystem.IsAboveSoftCap(PlayerData: any): boolean
	local TotalStars = StatSystem.GetTotalAllocatedStars(PlayerData)
	return TotalStars >= ProgressionBalance.Caps.TotalSoftCapStars
end

return StatSystem