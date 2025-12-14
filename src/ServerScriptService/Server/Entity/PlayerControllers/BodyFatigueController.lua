--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProgressionSystem = require(Server.Systems.ProgressionSystem)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Formulas = require(Shared.General.Formulas)
local Maid = require(Shared.General.Maid)
local DebugLogger = require(Shared.Debug.DebugLogger)

local BodyFatigueController = {}
BodyFatigueController.__index = BodyFatigueController

export type BodyFatigueController = typeof(setmetatable(
	{} :: {
		Controller: any,
		PlayerData: any,
		Maid: Maid.MaidSelf,
		UpdateAccumulator: number,
	},
	BodyFatigueController
))

local UPDATE_INTERVAL = 1.0
local FATIGUE_UPDATE_THRESHOLD = 0.1

function BodyFatigueController.new(CharacterController: any, PlayerData: any): BodyFatigueController
	local self = setmetatable({
		Controller = CharacterController,
		PlayerData = PlayerData,
		Maid = Maid.new(),
		UpdateAccumulator = 0,
	}, BodyFatigueController)

	return self
end

function BodyFatigueController:Update(DeltaTime: number)
	self.UpdateAccumulator += DeltaTime

	if self.UpdateAccumulator < UPDATE_INTERVAL then
		return
	end

	local AccumulatedTime = self.UpdateAccumulator
	self.UpdateAccumulator = 0

	ProgressionSystem.ProcessHunger(self.PlayerData, AccumulatedTime, self.Controller)
	ProgressionSystem.ProcessFat(self.PlayerData, AccumulatedTime, self.Controller)
end

function BodyFatigueController:AddFatigueFromStatGain(FatigueGain: number)
	if FatigueGain < FATIGUE_UPDATE_THRESHOLD then
		return
	end

	local CurrentFatigue = self.Controller.StatManager:GetStat(StatTypes.BODY_FATIGUE)
	local MaxFatigue = self.Controller.StatManager:GetStat(StatTypes.MAX_BODY_FATIGUE)

	local NewFatigue = math.min(MaxFatigue, CurrentFatigue + FatigueGain)

	self.Controller.StatManager:SetStat(StatTypes.BODY_FATIGUE, NewFatigue)
end

function BodyFatigueController:CanGainStats(): boolean
	local CanTrain, Reason = ProgressionSystem.CanTrain(self.PlayerData)
	if not CanTrain then
		DebugLogger.Info("BodyFatigueController", "Cannot train: %s", Reason or "Unknown")
	end
	return CanTrain
end

function BodyFatigueController:GetStatGainMultiplier(): number
	local CurrentFatigue = self.PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = self.PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100
	local FatiguePercent = Formulas.Percentage(CurrentFatigue, MaxFatigue)

	if FatiguePercent >= 50 then
		return 0.5
	end

	return 1.0
end

function BodyFatigueController:GetStaminaDrainMultiplier(): number
	local CurrentFatigue = self.PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = self.PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100
	local FatiguePercent = Formulas.Percentage(CurrentFatigue, MaxFatigue)

	if FatiguePercent >= 70 then
		return 1.5
	elseif FatiguePercent >= 50 then
		return 1.25
	end

	return 1.0
end

function BodyFatigueController:Rest()
	ProgressionSystem.RestoreFatigue(self.PlayerData)
	self.Controller.StatManager:SetStat(StatTypes.BODY_FATIGUE, 0)

	DebugLogger.Info("BodyFatigueController", "Rested %s", self.Controller.Character.Name)
end

function BodyFatigueController:Destroy()
	DebugLogger.Info("BodyFatigueController", "Destroying BodyFatigueController")
	self.Maid:DoCleaning()
end

return BodyFatigueController
