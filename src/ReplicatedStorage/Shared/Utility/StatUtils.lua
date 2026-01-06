--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)
local ProgressionFormulas = require(Shared.Utility.ProgressionFormulas)
local StatDefaults = require(Shared.Config.Balance.StatDefaults)

local StatUtils = {}

StatUtils.TRAINABLE_STATS = ProgressionBalance.TrainableStats
StatUtils.TOTAL_SOFT_CAP_STARS = ProgressionBalance.Caps.TotalSoftCapStars
StatUtils.MAX_STARS_PER_STAT = ProgressionBalance.Caps.MaxStarsPerStat
StatUtils.HARD_CAP_TOTAL_STARS = ProgressionBalance.Caps.HardCapTotalStars

function StatUtils.IsTrainableStat(StatName: string): boolean
	return ProgressionFormulas.IsTrainableStat(StatName)
end

function StatUtils.GetBaseValue(StatName: string): number
	return StatDefaults[StatName] or 0
end

function StatUtils.GetStarBonus(StatName: string): number
	return ProgressionBalance.StarBonuses[StatName] or 0
end

function StatUtils.CalculateStatValue(StatName: string, Stars: number): number
	return ProgressionFormulas.GetStatValue(StatName, Stars)
end

function StatUtils.GetStarTier(TotalStars: number): { Name: string, Color: Color3 }
	return ProgressionFormulas.GetStarTier(TotalStars)
end

return StatUtils