local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)

local StatUtils = {}

StatUtils.TRAINABLE_STATS = {
	StatTypes.DURABILITY,
	StatTypes.RUN_SPEED,
	StatTypes.STRIKING_POWER,
	StatTypes.STRIKE_SPEED,
	StatTypes.MUSCLE,
	StatTypes.MAX_STAMINA,
}

StatUtils.TOTAL_SOFT_CAP_STARS = StatBalance.Caps.TOTAL_SOFT_CAP_STARS
StatUtils.MAX_STARS_PER_STAT = StatBalance.Caps.MAX_STARS_PER_STAT
StatUtils.HARD_CAP_TOTAL_STARS = StatBalance.Caps.HARD_CAP_TOTAL_STARS

function StatUtils.IsTrainableStat(StatName: string): boolean
	for _, Stat in StatUtils.TRAINABLE_STATS do
		if Stat == StatName then
			return true
		end
	end
	return false
end

function StatUtils.GetBaseValue(StatName: string): number
	return StatBalance.Defaults[StatName] or 0
end

function StatUtils.GetStarBonus(StatName: string): number
	return StatBalance.StarBonuses[StatName] or 0
end

function StatUtils.CalculateStatValue(StatName: string, Stars: number): number
	local Base = StatUtils.GetBaseValue(StatName)
	local Bonus = StatUtils.GetStarBonus(StatName)
	return Base + (Stars * Bonus)
end

function StatUtils.GetStarTier(TotalStars: number): {Name: string, Color: Color3}
	for _, Tier in StatBalance.StarTiers do
		if TotalStars >= Tier.Min and TotalStars <= Tier.Max then
			return {Name = Tier.Name, Color = Tier.Color}
		end
	end

	local LastTier = StatBalance.StarTiers[#StatBalance.StarTiers]
	return {Name = LastTier.Name, Color = LastTier.Color}
end

return StatUtils