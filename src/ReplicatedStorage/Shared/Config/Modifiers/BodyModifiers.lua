--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Config.Enums.StatTypes)
local BodyFormulas = require(Shared.Utility.BodyFormulas)
local ProgressionFormulas = require(Shared.Utility.ProgressionFormulas)

export type ModifierConfig = {
	Type: string,
	Priority: number,
	Calculate: (BaseValue: number, StatManager: any, Data: any?) -> number,
}

local BodyModifiers: { ModifierConfig } = {
	{
		Type = "MaxHealth",
		Priority = 100,
		Calculate = function(BaseMaxHealth, StatManager, _)
			local Fat = StatManager:GetStat(StatTypes.FAT)
			local HealthBonus = BodyFormulas.GetHealthBonusFromFat(Fat)
			return BaseMaxHealth + HealthBonus
		end,
	},

	{
		Type = "Speed",
		Priority = 200,
		Calculate = function(BaseSpeed, StatManager, _)
			local Fat = StatManager:GetStat(StatTypes.FAT)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local FatPenalty = BodyFormulas.GetCappedFatSpeedPenalty(BaseSpeed, Fat, MuscleStars)
			return BaseSpeed - FatPenalty
		end,
	},

	{
		Type = "Speed",
		Priority = 201,
		Calculate = function(BaseSpeed, StatManager, _)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local Penalty = BodyFormulas.GetMuscleSpeedPenalty(MuscleStars)
			return BaseSpeed * (1 - Penalty)
		end,
	},

	{
		Type = "StrikeSpeed",
		Priority = 200,
		Calculate = function(BaseSpeed, StatManager, _)
			local Fat = StatManager:GetStat(StatTypes.FAT)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local Penalty = BodyFormulas.GetFatStrikeSpeedPenalty(Fat, MuscleStars)
			return BaseSpeed * (1 - Penalty)
		end,
	},

	{
		Type = "StrikeSpeed",
		Priority = 201,
		Calculate = function(BaseSpeed, StatManager, _)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local Penalty = BodyFormulas.GetMuscleStrikeSpeedPenalty(MuscleStars)
			return BaseSpeed * (1 - Penalty)
		end,
	},

	{
		Type = "Attack",
		Priority = 201,
		Calculate = function(Damage, StatManager, _)
			local MuscleStars = StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
			local MuscleBonus = BodyFormulas.GetMuscleStrikingPowerBonus(MuscleStars)
			return Damage + MuscleBonus
		end,
	},

	{
		Type = "Damage",
		Priority = 150,
		Calculate = function(IncomingDamage, StatManager, _)
			local DurabilityStars = StatManager:GetStat(StatTypes.DURABILITY .. "_Stars") or 0
			local DamageReduction = BodyFormulas.GetDurabilityDamageReduction(DurabilityStars)
			return IncomingDamage * (1 - DamageReduction)
		end,
	},

	{
		Type = "Attack",
		Priority = 150,
		Calculate = function(BaseDamage, StatManager, _)
			local StrikingPowerStars = StatManager:GetStat(StatTypes.STRIKING_POWER .. "_Stars") or 0
			local Bonus = ProgressionFormulas.GetStatBonus("StrikingPower", StrikingPowerStars)
			return BaseDamage + Bonus
		end,
	},

	{
		Type = "StrikeSpeed",
		Priority = 150,
		Calculate = function(_, StatManager, _)
			local StrikeSpeedStars = StatManager:GetStat(StatTypes.STRIKE_SPEED .. "_Stars") or 0
			local Bonus = ProgressionFormulas.GetStatBonus("StrikeSpeed", StrikeSpeedStars)
			return 1.0 + Bonus
		end,
	},
}

return BodyModifiers