--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)

export type ModifierConfig = {
	Type: string,
	Priority: number,
	Calculate: (BaseValue: number, StatManager: any, Data: any?) -> number,
}

local BodyCompositionModifiers: {ModifierConfig} = {
	{
		Type = "MaxHealth",
		Priority = 100,
		Calculate = function(BaseMaxHealth, StatManager, _)
			local Fat = StatManager:GetStat(StatTypes.FAT)
			local HealthBonus = Fat / TrainingBalance.FatSystem.HEALTH_PER_FAT
			return BaseMaxHealth + HealthBonus
		end,
	},

	{
		Type = "Speed",
		Priority = 200,
		Calculate = function(BaseSpeed, StatManager, _)
			local Fat = StatManager:GetStat(StatTypes.FAT)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local MuscleBonus = StatBalance.StarBonuses[StatTypes.MUSCLE] or 0
			local MuscleValue = MuscleBonus * MuscleStars

			if Fat > MuscleValue then
				local ExcessFat = Fat - MuscleValue
				local SpeedReduction = ExcessFat * TrainingBalance.FatSystem.FAT_RUNSPEED_REDUCTION_PER_FAT
				local MaxReduction = BaseSpeed * (TrainingBalance.FatSystem.RUNSPEED_MAX_PENALTY_PERCENT / 100)

				local CappedReduction = math.min(SpeedReduction, MaxReduction)
				return BaseSpeed - CappedReduction
			end

			return BaseSpeed
		end,
	},

	{
		Type = "Speed",
		Priority = 201,
		Calculate = function(BaseSpeed, StatManager, _)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local Penalty = MuscleStars * TrainingBalance.MuscleSystem.RUNSPEED_PENALTY_PER_MUSCLE
			return BaseSpeed * (1 - Penalty)
		end,
	},

	{
		Type = "StrikeSpeed",
		Priority = 200,
		Calculate = function(BaseSpeed, StatManager, _)
			local Fat = StatManager:GetStat(StatTypes.FAT)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local MuscleBonus = StatBalance.StarBonuses[StatTypes.MUSCLE] or 0
			local MuscleValue = MuscleBonus * MuscleStars

			if Fat > MuscleValue then
				local ExcessFat = Fat - MuscleValue
				local Penalty = ExcessFat * TrainingBalance.FatSystem.STRIKESPEED_PENALTY_PER_FAT
				return BaseSpeed * (1 - Penalty)
			end

			return BaseSpeed
		end,
	},

	{
		Type = "StrikeSpeed",
		Priority = 201,
		Calculate = function(BaseSpeed, StatManager, _)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local Penalty = MuscleStars * TrainingBalance.MuscleSystem.STRIKESPEED_PENALTY_PER_MUSCLE
			return BaseSpeed * (1 - Penalty)
		end,
	},

	{
		Type = "Attack",
		Priority = 201,
		Calculate = function(Damage, StatManager, _)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local MaxStars = StatBalance.Caps.PER_STAT_MAX_STARS
			local MuscleBonus = MuscleStars * StatBalance.StarBonuses[StatTypes.MUSCLE]

			local StarsPercent = (MuscleStars / MaxStars) * 100
			if StarsPercent >= TrainingBalance.MuscleSystem.OVER_TRAINING_THRESHOLD_PERCENT then
				MuscleBonus = MuscleBonus * (1 - (TrainingBalance.MuscleSystem.OVERTRAINED_SP_PENALTY_PERCENT / 100))
			end

			return Damage + MuscleBonus
		end,
	},

	{
		Type = "Damage",
		Priority = 150,
		Calculate = function(IncomingDamage, StatManager, _)
			local DurabilityStars = StatManager:GetStat(StatTypes.DURABILITY .. "_Stars") or 0
			local DurabilityValue = DurabilityStars * StatBalance.StarBonuses[StatTypes.DURABILITY]

			local DAMAGE_REDUCTION_PER_POINT = 0.005
			local DamageReduction = DurabilityValue * DAMAGE_REDUCTION_PER_POINT

			DamageReduction = math.min(DamageReduction, 0.60)

			return IncomingDamage * (1 - DamageReduction)
		end,
	},

	{
		Type = "Attack",
		Priority = 150,
		Calculate = function(BaseDamage, StatManager, _)
			local StrikingPowerStars = StatManager:GetStat(StatTypes.STRIKING_POWER .. "_Stars") or 0
			local StrikingPowerValue = StrikingPowerStars * StatBalance.StarBonuses[StatTypes.STRIKING_POWER]

			return BaseDamage + StrikingPowerValue
		end,
	},

	{
		Type = "StrikeSpeed",
		Priority = 150,
		Calculate = function(_, StatManager, _)
			local StrikeSpeedStars = StatManager:GetStat(StatTypes.STRIKE_SPEED .. "_Stars") or 0
			local StrikeSpeedValue = StrikeSpeedStars * StatBalance.StarBonuses[StatTypes.STRIKE_SPEED]

			return 1.0 + StrikeSpeedValue
		end,
	},
}

return BodyCompositionModifiers