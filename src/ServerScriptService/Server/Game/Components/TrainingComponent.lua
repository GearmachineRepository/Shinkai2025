--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatSystem = require(Server.Game.Systems.StatSystem)
local ProgressionSystem = require(Server.Game.Systems.ProgressionSystem)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local Maid = require(Shared.General.Maid)

export type TrainingComponent = {
	Entity: any,
	StartTraining: (self: TrainingComponent, TrainingType: string) -> (),
	StopTraining: (self: TrainingComponent) -> (),
	ProcessTraining: (self: TrainingComponent, DeltaTime: number) -> (),
	GrantStatGain: (self: TrainingComponent, StatName: string, Amount: number, FatigueGainOverride: number?) -> (),
	CanTrain: (self: TrainingComponent) -> boolean,
	AllocateStatPoint: (self: TrainingComponent, StatName: string) -> boolean,
	GetTotalAllocatedStars: (self: TrainingComponent) -> number,
	Destroy: (self: TrainingComponent) -> (),
}

type TrainingComponentInternal = TrainingComponent & {
	PlayerData: any,
	CurrentTraining: string?,
	Maid: Maid.MaidSelf,
}

local TrainingComponent = {}
TrainingComponent.__index = TrainingComponent

function TrainingComponent.new(Entity: any, PlayerData: any): TrainingComponent
	local self: TrainingComponentInternal = setmetatable({
		Entity = Entity,
		PlayerData = PlayerData,
		CurrentTraining = nil,
		Maid = Maid.new(),
	}, TrainingComponent) :: any

	local Character = self.Entity.Character
	if Character then
		for _, StatName in { "MaxStamina", "Durability", "RunSpeed", "StrikingPower", "StrikeSpeed", "Muscle" } do
			local XP = self.PlayerData.Stats[StatName .. "_XP"] or 0
			local Stars = self.PlayerData.Stats[StatName .. "_Stars"] or 0
			local AvailablePoints = self.PlayerData.Stats[StatName .. "_AvailablePoints"] or 0

			Character:SetAttribute(StatName .. "_XP", XP)
			Character:SetAttribute(StatName .. "_Stars", Stars)
			Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
		end
	end

	return self
end

function TrainingComponent:StartTraining(TrainingType: string)
	self.CurrentTraining = TrainingType
end

function TrainingComponent:StopTraining()
	self.CurrentTraining = nil
end

function TrainingComponent:ProcessTraining(_: number)
	if not self.CurrentTraining then
		return
	end
end

function TrainingComponent:GrantStatGain(StatName: string, Amount: number, _FatigueGainOverride: number?)
	if Amount <= 0 then
		return
	end

	local FinalAmount = Amount
	if self.Entity.Components.Sweat then
		FinalAmount = Amount * self.Entity.Components.Sweat:GetStatGainMultiplier()
	end

	local _XPAwarded = ProgressionSystem.AwardTrainingXP(self.PlayerData, StatName, FinalAmount, self.Entity)

	StatSystem.UpdateAvailablePoints(self.PlayerData, StatName)

	local Character = self.Entity.Character
	if Character then
		local XPValue = self.PlayerData.Stats[StatName .. "_XP"]
		Character:SetAttribute(StatName .. "_XP", XPValue)

		local AvailablePoints = self.PlayerData.Stats[StatName .. "_AvailablePoints"]
		Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)
	end
end

function TrainingComponent:CanTrain(): boolean
	if not self.Entity.Components.BodyFatigue then
		return true
	end

	return self.Entity.Components.BodyFatigue:CanGainStats()
end

function TrainingComponent:AllocateStatPoint(StatName: string): boolean
	local Success, ErrorMessage = StatSystem.AllocateStar(self.PlayerData, StatName)

	if not Success then
		warn("Failed to allocate star:", ErrorMessage)
		return false
	end

	local NewStars = self.PlayerData.Stats[StatName .. "_Stars"]
	local BaseValue = StatBalance.Defaults[StatName] or 0
	local NewStatValue = StatSystem.CalculateStatValue(BaseValue, NewStars, StatName)

	self.Entity.Stats:SetStat(StatName, NewStatValue)

	local Character = self.Entity.Character
	if Character then
		Character:SetAttribute(StatName .. "_Stars", NewStars)
		StatSystem.UpdateAvailablePoints(self.PlayerData, StatName)
		Character:SetAttribute(StatName .. "_AvailablePoints", self.PlayerData.Stats[StatName .. "_AvailablePoints"])
	end

	return true
end

function TrainingComponent:GetTotalAllocatedStars(): number
	return StatSystem.GetTotalAllocatedStars(self.PlayerData)
end

function TrainingComponent:Destroy()
	self.Maid:DoCleaning()
end

return TrainingComponent
