--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StatTypes = require(Shared.Config.Enums.StatTypes)
local StatSystem = require(Server.Game.Systems.StatSystem)
local FatigueBalance = require(Shared.Config.Body.FatigueBalance)
local BodyBalance = require(Shared.Config.Body.BodyBalance)
local HungerBalance = require(Shared.Config.Body.HungerBalance)
local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)

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

	if FatiguePercent < FatigueBalance.Fatigue.TrainingLockoutPercent then
		return 1.0
	end

	local ExcessFatigue = FatiguePercent - FatigueBalance.Fatigue.TrainingLockoutPercent
	local MaxExcess = 100 - FatigueBalance.Fatigue.TrainingLockoutPercent
	local PenaltyRatio = ExcessFatigue / MaxExcess

	return 1.0 - PenaltyRatio
end

function ProgressionSystem.AwardTrainingXP(PlayerData: any, StatType: string, BaseXP: number, Entity: any?): number
	local XPMultiplier = ProgressionBalance.XPRates.BaseRate

	if Entity and Entity.IsPlayer and Entity.Player then
		local IsPremium = Entity.Player.MembershipType == Enum.MembershipType.Premium
		if IsPremium then
			XPMultiplier *= ProgressionBalance.XPRates.PremiumMultiplier
		end
	end

	if StatSystem.IsAboveSoftCap(PlayerData) then
		XPMultiplier *= ProgressionBalance.XPRates.AfterSoftCapMultiplier
	end

	local FatiguePenalty = ProgressionSystem.GetFatiguePenalty(PlayerData)
	XPMultiplier *= FatiguePenalty

	local FinalXP = BaseXP * XPMultiplier

	if FinalXP > 0 then
		PlayerData.Stats[StatType .. "_XP"] = (PlayerData.Stats[StatType .. "_XP"] or 0) + FinalXP

		if Entity and Entity.Stats then
			local FatigueGain = FinalXP * FatigueBalance.Fatigue.XPToFatigueRatio
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

	if CurrentHunger < HungerBalance.MuscleLoss.Threshold then
		local MuscleLoss = HungerBalance.MuscleLoss.RatePerSecond * DeltaTime
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

	local FatRequired = MuscleXP * HungerBalance.MuscleLoss.FatToMuscleConversion

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
	if HungerPercent >= BodyBalance.Fat.GainThresholdPercent then
		local MaxFat = BodyBalance.Fat.MaxFat
		-- TODO: Check for Jigoro clan, set MaxFat = 750 if they have it

		if CurrentFat < MaxFat then
			local FatGain = BodyBalance.Fat.GainRatePerSecond * DeltaTime
			local NewFat = math.min(MaxFat, CurrentFat + FatGain)
			CharacterController.StatManager:SetStat(StatTypes.FAT, NewFat)
		end
		-- Lose fat when below X% hunger
	else
		if CurrentFat > 0 then
			local FatLoss = BodyBalance.Fat.LossRatePerSecond * DeltaTime
			local NewFat = math.max(0, CurrentFat - FatLoss)
			CharacterController.StatManager:SetStat(StatTypes.FAT, NewFat)
		end
	end
end

return ProgressionSystem
