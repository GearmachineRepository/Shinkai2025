--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StyleConfig = require(Shared.Config.Styles.StyleConfig)
local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)
local BodyBalance = require(Shared.Config.Body.BodyBalance)

export type PlayerStats = {
	StrikingPower: number,
	StrikeSpeed: number,
	Muscle: number,
	RunSpeed: number,
	Durability: number,
	MaxStamina: number,
	Fat: number,
	Height: number,
}

export type ScalingResult = {
	Damage: number,
	Speed: number,
	Range: number,
	Stun: number,
	StaminaCost: number,
}

export type AttackProperties = {
	Style: string?,
	IsSkill: boolean?,
	IsKick: boolean?,
}

export type ActiveBoosts = {
	DamageMultiplier: number?,
	SpeedMultiplier: number?,
	RangeMultiplier: number?,
	StunMultiplier: number?,
}

local StatScalingFormulas = {}

local DEFAULT_STYLE = "Fists"
local HEIGHT_BASE = 1.0
local SKILL_SCALING_PERCENT = 0.2

function StatScalingFormulas.GetStatValueFromStars(StatName: string, Stars: number): number
	local StarBonus = ProgressionBalance.StarBonuses[StatName]
	if not StarBonus then
		return 0
	end
	return Stars * StarBonus
end

function StatScalingFormulas.GetTotalPower(Stats: PlayerStats): number
	local Total = Stats.StrikingPower
		+ Stats.StrikeSpeed
		+ Stats.Muscle
		+ Stats.RunSpeed
		+ Stats.Fat
	return Total / 30
end

function StatScalingFormulas.CalculateDamageScaling(
	Stats: PlayerStats,
	Balance: StyleConfig.BalanceConfig
): number
	local BonusPercent = 0
	local DamageScaling = Balance.DamageScaling

	if DamageScaling.StrikingPower then
		local PercentPerPoint = DamageScaling.StrikingPower
		BonusPercent += Stats.StrikingPower * PercentPerPoint
	end

	if DamageScaling.Muscle then
		local PercentPerPoint = DamageScaling.Muscle
		local MuscleValue = Stats.Muscle

		local MaxStars = ProgressionBalance.Caps.MaxStarsPerStat
		local MuscleStars = MuscleValue / ProgressionBalance.StarBonuses.Muscle
		local StarsPercent = (MuscleStars / MaxStars) * 100

		if StarsPercent >= BodyBalance.Muscle.OverTrainingThresholdPercent then
			local PenaltyMultiplier = 1 - (BodyBalance.Muscle.OvertrainedStrikingPowerPenaltyPercent / 100)
			MuscleValue *= PenaltyMultiplier
		end

		BonusPercent += MuscleValue * PercentPerPoint
	end

	if DamageScaling.StrikeSpeed then
		local PercentPerPoint = DamageScaling.StrikeSpeed
		BonusPercent += Stats.StrikeSpeed * PercentPerPoint
	end

	if DamageScaling.Fat and Stats.Fat > 0 then
		local PercentPerPoint = DamageScaling.Fat
		BonusPercent += Stats.Fat * PercentPerPoint
	end

	return 1 + (BonusPercent / 100)
end

function StatScalingFormulas.CalculateSpeedScaling(Stats: PlayerStats): number
	local SpeedMultiplier = 1.0

	local StrikeSpeedBonus = Stats.StrikeSpeed / 200
	SpeedMultiplier *= 1 + StrikeSpeedBonus

	local MuscleStars = Stats.Muscle / ProgressionBalance.StarBonuses.Muscle
	local MusclePenalty = MuscleStars * BodyBalance.Muscle.StrikeSpeedPenaltyPerMuscle
	SpeedMultiplier *= 1 - MusclePenalty

	local MuscleValue = MuscleStars * ProgressionBalance.StarBonuses.Muscle
	if Stats.Fat > MuscleValue then
		local ExcessFat = Stats.Fat - MuscleValue
		local FatPenalty = ExcessFat * BodyBalance.Fat.StrikeSpeedPenaltyPerFat
		SpeedMultiplier *= 1 - FatPenalty
	end

	local HeightPenalty = Stats.Height / HEIGHT_BASE
	SpeedMultiplier /= HeightPenalty

	return math.max(0.1, SpeedMultiplier)
end

function StatScalingFormulas.CalculateRangeScaling(Stats: PlayerStats): number
	return Stats.Height / HEIGHT_BASE
end

function StatScalingFormulas.Scale(
	Properties: AttackProperties,
	Stats: PlayerStats,
	Boosts: ActiveBoosts?
): ScalingResult
	local StyleName = Properties.Style or DEFAULT_STYLE
	local Balance = StyleConfig.GetBalance(StyleName)

	local Result: ScalingResult = {
		Damage = 1.0,
		Speed = 1.0,
		Range = 1.0,
		Stun = 1.0,
		StaminaCost = 1.0,
	}
	print(StyleName)
	Result.Damage *= Balance.BaseDamage
	Result.Speed *= Balance.BaseSpeed
	Result.Range *= Balance.BaseRange
	Result.Stun *= Balance.BaseStun
	Result.StaminaCost *= Balance.BaseStaminaCost

	local DamageScaling = StatScalingFormulas.CalculateDamageScaling(Stats, Balance)
	Result.Damage *= DamageScaling

	if Properties.IsSkill then
		local SkillBonus = Stats.StrikingPower * SKILL_SCALING_PERCENT
		Result.Damage *= 1 + (SkillBonus / 100)
	end

	local SpeedScaling = StatScalingFormulas.CalculateSpeedScaling(Stats)
	Result.Speed *= SpeedScaling

	local RangeScaling = StatScalingFormulas.CalculateRangeScaling(Stats)
	Result.Range *= RangeScaling

	if StyleName == "Wrestling" then
		local WrestlingBonus = StyleConfig.GetPassiveMultiplier("WrestlingMuscleDamageBonus")
		if WrestlingBonus then
			Result.Damage *= WrestlingBonus
		end
	end

	if Boosts then
		if Boosts.DamageMultiplier then
			Result.Damage *= Boosts.DamageMultiplier
		end
		if Boosts.SpeedMultiplier then
			Result.Speed *= Boosts.SpeedMultiplier
		end
		if Boosts.RangeMultiplier then
			Result.Range *= Boosts.RangeMultiplier
		end
		if Boosts.StunMultiplier then
			Result.Stun *= Boosts.StunMultiplier
		end
	end

	return Result
end

function StatScalingFormulas.ApplyDamageReduction(
	IncomingDamage: number,
	DurabilityValue: number
): number
	local ReductionRate = BodyBalance.DamageReduction.ReductionPerDurabilityPoint
	local MaxReduction = BodyBalance.DamageReduction.MaxReductionPercent / 100
	local Reduction = math.min(DurabilityValue * ReductionRate, MaxReduction)
	return IncomingDamage * (1 - Reduction)
end

function StatScalingFormulas.GetEffectiveRunSpeed(
	BaseSpeed: number,
	Stats: PlayerStats
): number
	local FinalSpeed = BaseSpeed

	local MuscleStars = Stats.Muscle / ProgressionBalance.StarBonuses.Muscle
	local MusclePenalty = MuscleStars * BodyBalance.Muscle.RunSpeedPenaltyPerMuscle
	FinalSpeed *= 1 - MusclePenalty

	local MuscleValue = MuscleStars * ProgressionBalance.StarBonuses.Muscle
	if Stats.Fat > MuscleValue then
		local ExcessFat = Stats.Fat - MuscleValue
		local RawPenalty = ExcessFat * BodyBalance.Fat.RunSpeedReductionPerFat
		local MaxPenalty = BaseSpeed * (BodyBalance.Fat.RunSpeedMaxPenaltyPercent / 100)
		local FatPenalty = math.min(RawPenalty, MaxPenalty)
		FinalSpeed -= FatPenalty
	end

	return math.max(0, FinalSpeed)
end

function StatScalingFormulas.GetStatsFromPlayerData(
	PlayerData: { Stats: { [string]: number } },
	Height: number?
): PlayerStats
	local Stats = PlayerData.Stats

	local StrikingPowerStars = Stats.StrikingPower_Stars or 0
	local StrikeSpeedStars = Stats.StrikeSpeed_Stars or 0
	local MuscleStars = Stats.Muscle_Stars or 0
	local RunSpeedStars = Stats.RunSpeed_Stars or 0
	local DurabilityStars = Stats.Durability_Stars or 0
	local MaxStaminaStars = Stats.MaxStamina_Stars or 0

	return {
		StrikingPower = StatScalingFormulas.GetStatValueFromStars("StrikingPower", StrikingPowerStars),
		StrikeSpeed = StatScalingFormulas.GetStatValueFromStars("StrikeSpeed", StrikeSpeedStars),
		Muscle = StatScalingFormulas.GetStatValueFromStars("Muscle", MuscleStars),
		RunSpeed = StatScalingFormulas.GetStatValueFromStars("RunSpeed", RunSpeedStars),
		Durability = StatScalingFormulas.GetStatValueFromStars("Durability", DurabilityStars),
		MaxStamina = StatScalingFormulas.GetStatValueFromStars("MaxStamina", MaxStaminaStars),
		Fat = Stats.Fat or 0,
		Height = Height or 1.0,
	}
end

function StatScalingFormulas.GetBoostsFromEntity(Entity: any): ActiveBoosts
	local Boosts: ActiveBoosts = {}

	if not Entity or not Entity.Boosts then
		return Boosts
	end

	local BoostsFolder = Entity.Boosts
	if typeof(BoostsFolder) ~= "Instance" then
		return Boosts
	end

	for _, Child in BoostsFolder:GetChildren() do
		if Child:IsA("NumberValue") then
			if Child.Name == "DamageMultiplier" then
				Boosts.DamageMultiplier = (Boosts.DamageMultiplier or 1) * Child.Value
			elseif Child.Name == "SpeedMultiplier" or Child.Name == "StrikingSpeedMultiplier" then
				Boosts.SpeedMultiplier = (Boosts.SpeedMultiplier or 1) * Child.Value
			elseif Child.Name == "RangeMultiplier" then
				Boosts.RangeMultiplier = (Boosts.RangeMultiplier or 1) * Child.Value
			elseif Child.Name == "StunMultiplier" then
				Boosts.StunMultiplier = (Boosts.StunMultiplier or 1) * Child.Value
			end
		end
	end

	return Boosts
end

function StatScalingFormulas.ApplyScalingToDamage(
	BaseDamage: number,
	Scaling: ScalingResult
): number
	return BaseDamage * Scaling.Damage
end

function StatScalingFormulas.ApplyScalingToStun(
	BaseStun: number,
	Scaling: ScalingResult
): number
	return BaseStun * Scaling.Stun
end

function StatScalingFormulas.ApplyScalingToRange(
	BaseRange: number,
	Scaling: ScalingResult
): number
	return BaseRange * Scaling.Range
end

function StatScalingFormulas.ApplyScalingToStaminaCost(
	BaseStaminaCost: number,
	Scaling: ScalingResult
): number
	return BaseStaminaCost * Scaling.StaminaCost
end

function StatScalingFormulas.GetAnimationSpeedMultiplier(Scaling: ScalingResult): number
	return Scaling.Speed
end

return StatScalingFormulas