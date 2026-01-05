--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local BodyBalance = require(Shared.Config.Body.BodyBalance)
local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)

local BodyFormulas = {}

function BodyFormulas.GetHealthBonusFromFat(Fat: number): number
	return Fat / BodyBalance.Fat.HealthPerFat
end

function BodyFormulas.GetFatSpeedPenalty(Fat: number, MuscleStars: number): number
	local MuscleBonus = ProgressionBalance.StarBonuses.Muscle or 0
	local MuscleValue = MuscleBonus * MuscleStars

	if Fat <= MuscleValue then
		return 0
	end

	local ExcessFat = Fat - MuscleValue
	return ExcessFat * BodyBalance.Fat.RunSpeedReductionPerFat
end

function BodyFormulas.GetCappedFatSpeedPenalty(BaseSpeed: number, Fat: number, MuscleStars: number): number
	local RawPenalty = BodyFormulas.GetFatSpeedPenalty(Fat, MuscleStars)
	local MaxPenalty = BaseSpeed * (BodyBalance.Fat.RunSpeedMaxPenaltyPercent / 100)
	return math.min(RawPenalty, MaxPenalty)
end

function BodyFormulas.GetFatStrikeSpeedPenalty(Fat: number, MuscleStars: number): number
	local MuscleBonus = ProgressionBalance.StarBonuses.Muscle or 0
	local MuscleValue = MuscleBonus * MuscleStars

	if Fat <= MuscleValue then
		return 0
	end

	local ExcessFat = Fat - MuscleValue
	return ExcessFat * BodyBalance.Fat.StrikeSpeedPenaltyPerFat
end

function BodyFormulas.GetMuscleSpeedPenalty(MuscleStars: number): number
	return MuscleStars * BodyBalance.Muscle.RunSpeedPenaltyPerMuscle
end

function BodyFormulas.GetMuscleStrikeSpeedPenalty(MuscleStars: number): number
	return MuscleStars * BodyBalance.Muscle.StrikeSpeedPenaltyPerMuscle
end

function BodyFormulas.GetMuscleStrikingPowerBonus(MuscleStars: number): number
	local MuscleBonus = MuscleStars * ProgressionBalance.StarBonuses.Muscle
	local MaxStars = ProgressionBalance.Caps.MaxStarsPerStat
	local StarsPercent = (MuscleStars / MaxStars) * 100

	if StarsPercent >= BodyBalance.Muscle.OverTrainingThresholdPercent then
		local PenaltyMultiplier = 1 - (BodyBalance.Muscle.OvertrainedStrikingPowerPenaltyPercent / 100)
		return MuscleBonus * PenaltyMultiplier
	end

	return MuscleBonus
end

function BodyFormulas.GetDurabilityDamageReduction(DurabilityStars: number): number
	local DurabilityValue = DurabilityStars * ProgressionBalance.StarBonuses.Durability
	local Reduction = DurabilityValue * BodyBalance.DamageReduction.ReductionPerDurabilityPoint
	return math.min(Reduction, BodyBalance.DamageReduction.MaxReductionPercent / 100)
end

function BodyFormulas.GetBodyScale(Muscle: number, Fat: number): number
	local MuscleContribution = Muscle * BodyBalance.BodyScaling.MuscleScaleMultiplier
	local FatContribution = Fat * BodyBalance.BodyScaling.FatScaleMultiplier
	local TotalScale = BodyBalance.BodyScaling.ScaleMin + MuscleContribution + FatContribution
	return math.clamp(TotalScale, BodyBalance.BodyScaling.ScaleMin, BodyBalance.BodyScaling.ScaleMax)
end

function BodyFormulas.GetFatGainRate(HungerPercent: number): number
	if HungerPercent >= BodyBalance.Fat.GainThresholdPercent then
		return BodyBalance.Fat.GainRatePerSecond
	end
	return 0
end

function BodyFormulas.GetFatLossRate(HungerPercent: number): number
	if HungerPercent < BodyBalance.Fat.GainThresholdPercent then
		return BodyBalance.Fat.LossRatePerSecond
	end
	return 0
end

function BodyFormulas.GetMaxFat(IsJigoro: boolean?): number
	if IsJigoro then
		return BodyBalance.Fat.MaxFatJigoro
	end
	return BodyBalance.Fat.MaxFat
end

function BodyFormulas.CalculateSpeedWithPenalties(BaseSpeed: number, Fat: number, MuscleStars: number): number
	local FatPenalty = BodyFormulas.GetCappedFatSpeedPenalty(BaseSpeed, Fat, MuscleStars)
	local MusclePenalty = BodyFormulas.GetMuscleSpeedPenalty(MuscleStars)
	return math.max(0, BaseSpeed - FatPenalty - (BaseSpeed * MusclePenalty))
end

function BodyFormulas.CalculateStrikeSpeedMultiplier(Fat: number, MuscleStars: number, StrikeSpeedStars: number): number
	local BaseMultiplier = 1.0 + (StrikeSpeedStars * ProgressionBalance.StarBonuses.StrikeSpeed)
	local FatPenalty = BodyFormulas.GetFatStrikeSpeedPenalty(Fat, MuscleStars)
	local MusclePenalty = BodyFormulas.GetMuscleStrikeSpeedPenalty(MuscleStars)
	return math.max(0.1, BaseMultiplier * (1 - FatPenalty) * (1 - MusclePenalty))
end

return BodyFormulas