--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)
local StatDefaults = require(Shared.Config.Balance.StatDefaults)

local ProgressionFormulas = {}

function ProgressionFormulas.GetXPForNextPoint(StatName: string, TotalPointsEarned: number): number
	local BaseThreshold = ProgressionBalance.XPThresholds[StatName]
	if not BaseThreshold then
		return 100
	end

	local TierIndex = math.floor(TotalPointsEarned / ProgressionBalance.XPTierSize)
	local Increment = ProgressionBalance.XPTierIncrement[StatName] or 100

	return BaseThreshold + (TierIndex * Increment)
end

function ProgressionFormulas.GetStatBonus(StatName: string, Stars: number): number
	local Bonus = ProgressionBalance.StarBonuses[StatName]
	if not Bonus then
		return 0
	end
	return Bonus * Stars
end

function ProgressionFormulas.GetStatValue(StatName: string, Stars: number): number
	local BaseValue = StatDefaults[StatName] or 0
	local Bonus = ProgressionFormulas.GetStatBonus(StatName, Stars)
	return BaseValue + Bonus
end

function ProgressionFormulas.GetStarTier(TotalStars: number): { Name: string, Color: Color3 }
	for _, Tier in ProgressionBalance.StarTiers do
		if TotalStars >= Tier.Min and TotalStars <= Tier.Max then
			return {
				Name = Tier.Name,
				Color = Color3.fromRGB(Tier.Color.R, Tier.Color.G, Tier.Color.B),
			}
		end
	end

	local LastTier = ProgressionBalance.StarTiers[#ProgressionBalance.StarTiers]
	return {
		Name = LastTier.Name,
		Color = Color3.fromRGB(LastTier.Color.R, LastTier.Color.G, LastTier.Color.B),
	}
end

function ProgressionFormulas.IsAtSoftCap(TotalStars: number): boolean
	return TotalStars >= ProgressionBalance.Caps.TotalSoftCapStars
end

function ProgressionFormulas.IsAtHardCap(TotalStars: number): boolean
	return TotalStars >= ProgressionBalance.Caps.HardCapTotalStars
end

function ProgressionFormulas.IsStatMaxed(StatStars: number): boolean
	return StatStars >= ProgressionBalance.Caps.MaxStarsPerStat
end

function ProgressionFormulas.GetXPMultiplier(TotalStars: number, IsPremium: boolean?): number
	local Multiplier = ProgressionBalance.XPRates.BaseRate

	if ProgressionFormulas.IsAtSoftCap(TotalStars) then
		Multiplier = Multiplier * ProgressionBalance.XPRates.AfterSoftCapMultiplier
	end

	if IsPremium then
		Multiplier = Multiplier * ProgressionBalance.XPRates.PremiumMultiplier
	end

	return Multiplier
end

function ProgressionFormulas.CalculateXPGain(BaseXP: number, TotalStars: number, IsPremium: boolean?): number
	local Multiplier = ProgressionFormulas.GetXPMultiplier(TotalStars, IsPremium)
	return BaseXP * Multiplier
end

function ProgressionFormulas.IsTrainableStat(StatName: string): boolean
	for _, TrainableStat in ProgressionBalance.TrainableStats do
		if TrainableStat == StatName then
			return true
		end
	end
	return false
end

function ProgressionFormulas.GetTotalStars(StatStars: { [string]: number }): number
	local Total = 0
	for StatName, Stars in StatStars do
		if ProgressionFormulas.IsTrainableStat(StatName) then
			Total += Stars
		end
	end
	return Total
end

function ProgressionFormulas.CanGainStar(StatName: string, CurrentStatStars: number, TotalStars: number): boolean
	if not ProgressionFormulas.IsTrainableStat(StatName) then
		return false
	end

	if ProgressionFormulas.IsStatMaxed(CurrentStatStars) then
		return false
	end

	if ProgressionFormulas.IsAtHardCap(TotalStars) then
		return false
	end

	return true
end

return ProgressionFormulas