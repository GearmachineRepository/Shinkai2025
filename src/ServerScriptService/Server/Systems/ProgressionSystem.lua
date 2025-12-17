--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StatSystem = require(Server.Systems.StatSystem)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)

local ProgressionSystem = {}

function ProgressionSystem.CanTrain(PlayerData: any): (boolean, string?)
	local CurrentFatigue = PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100

	local FatiguePercent = (CurrentFatigue / MaxFatigue) * 100

	if FatiguePercent >= 100 then
		return false, "Too fatigued to train. Rest at an apothecary or hospital."
	end

	return true
end

function ProgressionSystem.GetFatiguePenalty(PlayerData: any): number
	local CurrentFatigue = PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100
	local FatiguePercent = (CurrentFatigue / MaxFatigue) * 100

	if FatiguePercent >= 100 then
		return 0
	end

	if FatiguePercent < TrainingBalance.FatigueSystem.TRAINING_LOCKOUT_PERCENT then
		return 1.0
	end

	local ExcessFatigue = FatiguePercent - TrainingBalance.FatigueSystem.TRAINING_LOCKOUT_PERCENT
	local MaxExcess = 100 - TrainingBalance.FatigueSystem.TRAINING_LOCKOUT_PERCENT
	local PenaltyRatio = ExcessFatigue / MaxExcess

	return 1.0 - PenaltyRatio
end

function ProgressionSystem.AwardTrainingXP(PlayerData: any, StatType: string, BaseXP: number, Entity: any?): number
	local XPMultiplier = TrainingBalance.XPRates.BASE_RATE

	if Entity and Entity.IsPlayer and Entity.Player then
		local IsPremium = Entity.Player.MembershipType == Enum.MembershipType.Premium
		if IsPremium then
			XPMultiplier *= TrainingBalance.XPRates.PREMIUM_MULTIPLIER
		end
	end

	if StatSystem.IsAboveSoftCap(PlayerData) then
		XPMultiplier *= TrainingBalance.XPRates.AFTER_SOFT_CAP_MULTIPLIER
	end

	local FatiguePenalty = ProgressionSystem.GetFatiguePenalty(PlayerData)
	XPMultiplier *= FatiguePenalty

	local FinalXP = BaseXP * XPMultiplier

	if FinalXP > 0 then
		PlayerData.Stats[StatType .. "_XP"] = (PlayerData.Stats[StatType .. "_XP"] or 0) + FinalXP

		if Entity and Entity.Stats then
			local FatigueGain = FinalXP * TrainingBalance.FatigueSystem.XP_TO_FATIGUE_RATIO
			local CurrentFatigue = Entity.Stats:GetStat(StatTypes.BODY_FATIGUE) or 0
			local NewFatigue = math.min(100, CurrentFatigue + FatigueGain)
			Entity.Stats:SetStat(StatTypes.BODY_FATIGUE, NewFatigue)
		end

		StatSystem.UpdateAvailablePoints(PlayerData, StatType)
	end

	return FinalXP
end
function ProgressionSystem.RestoreFatigue(PlayerData: any)
	PlayerData.Stats[StatTypes.BODY_FATIGUE] = 0
end

function ProgressionSystem.ProcessHunger(_: any, DeltaTime: number, CharacterController: any?) -- PlayerData is unused
	if not CharacterController or not CharacterController.StatManager then
		return
	end

	local CurrentHunger = CharacterController.StatManager:GetStat(StatTypes.HUNGER)
	local CurrentMuscle = CharacterController.StatManager:GetStat(StatTypes.MUSCLE)

	if CurrentHunger < TrainingBalance.HungerSystem.MUSCLE_LOSS_THRESHOLD then
		local MuscleLoss = TrainingBalance.HungerSystem.MUSCLE_LOSS_RATE_PER_SECOND * DeltaTime
		local NewMuscle = math.max(0, CurrentMuscle - MuscleLoss)
		CharacterController.StatManager:SetStat(StatTypes.MUSCLE, NewMuscle)
	end
end

function ProgressionSystem.ConsumeFood(_: any, HungerRestoreAmount: number, CharacterController: any?) -- PlayerData is unused
	if not CharacterController or not CharacterController.StatManager then
		return
	end

	local CurrentHunger = CharacterController.StatManager:GetStat(StatTypes.HUNGER)
	local MaxHunger = CharacterController.StatManager:GetStat(StatTypes.MAX_HUNGER)

	local NewHunger = math.min(MaxHunger, CurrentHunger + HungerRestoreAmount)
	CharacterController.StatManager:SetStat(StatTypes.HUNGER, NewHunger)
end

function ProgressionSystem.ProcessMuscleTraining(
	_: any,
	MuscleXP: number,
	CharacterController: any?
): boolean -- PlayerData is unused
	if not CharacterController or not CharacterController.StatManager then
		return false
	end

	local CurrentFat = CharacterController.StatManager:GetStat(StatTypes.FAT)

	if CurrentFat <= 0 then
		return false
	end

	local FatRequired = MuscleXP * TrainingBalance.HungerSystem.FAT_TO_MUSCLE_CONVERSION

	if CurrentFat < FatRequired then
		return false
	end

	local NewFat = CurrentFat - FatRequired
	CharacterController.StatManager:SetStat(StatTypes.FAT, NewFat)

	return true
end

function ProgressionSystem.ProcessFat(_: any, DeltaTime: number, CharacterController: any?) -- PlayerData
	if not CharacterController or not CharacterController.StatManager then
		return
	end

	local CurrentHunger = CharacterController.StatManager:GetStat(StatTypes.HUNGER)
	local MaxHunger = CharacterController.StatManager:GetStat(StatTypes.MAX_HUNGER)
	local CurrentFat = CharacterController.StatManager:GetStat(StatTypes.FAT)

	local HungerPercent = (CurrentHunger / MaxHunger) * 100

	-- Gain fat when above X% hunger
	if HungerPercent >= TrainingBalance.FatSystem.FAT_GAIN_THRESHOLD_PERCENT then
		local MaxFat = TrainingBalance.FatSystem.MAX_FAT
		-- TODO: Check for Jigoro clan, set MaxFat = 750 if they have it

		if CurrentFat < MaxFat then
			local FatGain = TrainingBalance.FatSystem.FAT_GAIN_RATE_PER_SECOND * DeltaTime
			local NewFat = math.min(MaxFat, CurrentFat + FatGain)
			CharacterController.StatManager:SetStat(StatTypes.FAT, NewFat)
		end
		-- Lose fat when below X% hunger
	else
		if CurrentFat > 0 then
			local FatLoss = TrainingBalance.FatSystem.FAT_LOSS_RATE_PER_SECOND * DeltaTime
			local NewFat = math.max(0, CurrentFat - FatLoss)
			CharacterController.StatManager:SetStat(StatTypes.FAT, NewFat)
		end
	end
end

return ProgressionSystem
