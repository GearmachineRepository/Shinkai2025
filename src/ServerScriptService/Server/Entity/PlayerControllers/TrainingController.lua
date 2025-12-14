--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatSystem = require(Server.Systems.StatSystem)
local ProgressionSystem = require(Server.Systems.ProgressionSystem)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local DebugLogger = require(Shared.Debug.DebugLogger)
local Maid = require(Shared.General.Maid)

local TrainingController = {}
TrainingController.__index = TrainingController

export type TrainingController = typeof(setmetatable(
	{} :: {
		Controller: any,
		PlayerData: any,
		CurrentTraining: string?,
		Maid: Maid.MaidSelf,
	},
	TrainingController
))

function TrainingController.new(CharacterController: any, PlayerData: any): TrainingController
	local self = setmetatable({
		Controller = CharacterController,
		PlayerData = PlayerData,
		CurrentTraining = nil,
		Maid = Maid.new(),
	}, TrainingController)

	self:InitializeStatAttributes()

	return self
end

function TrainingController:InitializeStatAttributes()
	local Character = self.Controller.Character
	if not Character then
		return
	end

	for _, StatName in
		{
			"MaxStamina",
			"Durability",
			"RunSpeed",
			"StrikingPower",
			"StrikeSpeed",
			"Muscle",
		}
	do
		local XP = self.PlayerData.Stats[StatName .. "_XP"] or 0
		local Stars = self.PlayerData.Stats[StatName .. "_Stars"] or 0
		local AvailablePoints = self.PlayerData.Stats[StatName .. "_AvailablePoints"] or 0

		Character:SetAttribute(StatName .. "_XP", XP)
		Character:SetAttribute(StatName .. "_Stars", Stars)
		Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
	end
end

function TrainingController:StartTraining(TrainingType: string)
	self.CurrentTraining = TrainingType
end

function TrainingController:StopTraining()
	self.CurrentTraining = nil
end

function TrainingController:ProcessTraining(_: number)
	if not self.CurrentTraining then
		return
	end
end

function TrainingController:GrantStatGain(StatName: string, Amount: number, _FatigueGainOverride: number?)
	if Amount <= 0 then
		return
	end

	local FinalAmount = Amount
	if self.Controller.SweatController then
		FinalAmount = Amount * self.Controller.SweatController:GetStatGainMultiplier()
	end

	local XPAwarded = ProgressionSystem.AwardTrainingXP(self.PlayerData, StatName, FinalAmount, self.Controller)

	self:UpdateAvailablePoints(StatName)

	local Character = self.Controller.Character
	if Character then
		local XPValue = self.PlayerData.Stats[StatName .. "_XP"]
		Character:SetAttribute(StatName .. "_XP", XPValue)

		local AvailablePoints = self.PlayerData.Stats[StatName .. "_AvailablePoints"]
		Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
	end

	if XPAwarded > 0 then
		DebugLogger.Info(
			"TrainingController",
			"Awarded %.2f XP to %s for %s",
			XPAwarded,
			self.Controller.Character.Name,
			StatName
		)
	end
end

function TrainingController:AllocateStatPoint(StatName: string): boolean
	local Success, ErrorMessage = StatSystem.AllocateStar(self.PlayerData, StatName)

	if not Success then
		DebugLogger.Warning(
			"TrainingController",
			"Failed to allocate star for %s: %s",
			self.Controller.Character.Name,
			ErrorMessage
		)
		return false
	end

	local NewStars = self.PlayerData.Stats[StatName .. "_Stars"]
	local BaseValue = StatBalance.Defaults[StatName] or 0
	local NewStatValue = StatSystem.CalculateStatValue(BaseValue, NewStars, StatName)

	self.Controller.StatManager:SetStat(StatName, NewStatValue)

	local Character = self.Controller.Character
	if Character then
		Character:SetAttribute(StatName .. "_Stars", NewStars)

		self:UpdateAvailablePoints(StatName)
	end

	DebugLogger.Info(
		"TrainingController",
		"%s allocated star to %s (now %d stars)",
		self.Controller.Character.Name,
		StatName,
		NewStars
	)

	return true
end

function TrainingController:UpdateAvailablePoints(StatName: string)
	StatSystem.UpdateAvailablePoints(self.PlayerData, StatName)

	local Character = self.Controller.Character
	if Character then
		local AvailablePoints = self.PlayerData.Stats[StatName .. "_AvailablePoints"]
		Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
	end
end

function TrainingController:CanTrain(): boolean
	if not self.Controller.BodyFatigueController then
		return true
	end

	return self.Controller.BodyFatigueController:CanGainStats()
end

function TrainingController:GetTotalAllocatedStars(): number
	return StatSystem.GetTotalAllocatedStars(self.PlayerData)
end

function TrainingController:Destroy()
	self:StopTraining()
	DebugLogger.Info("TrainingController", "Destroying TrainingController")
	self.Maid:DoCleaning()
end

return TrainingController
