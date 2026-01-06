--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StatSystem = require(Server.Game.Systems.StatSystem)
local ProgressionSystem = require(Server.Game.Systems.ProgressionSystem)
local StatDefaults = require(Shared.Config.Balance.StatDefaults)

local TrainingComponent = {}
TrainingComponent.__index = TrainingComponent

TrainingComponent.ComponentName = "Training"
TrainingComponent.Dependencies = { "Stats" }

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	PlayerData: any,
	CurrentTraining: string?,
}

function TrainingComponent.new(Entity: Types.Entity, Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		PlayerData = Context.Data,
		CurrentTraining = nil,
	}, TrainingComponent) :: any

	local Character = Entity.Character
	if Character and self.PlayerData then
		for _, StatName in { "MaxStamina", "Durability", "RunSpeed", "StrikingPower", "StrikeSpeed", "Muscle" } do
			local XP = self.PlayerData.Stats[StatName .. "_XP"] or 0
			local Stars = self.PlayerData.Stats[StatName .. "_Stars"] or 0
			local Points = self.PlayerData.Stats[StatName .. "_Points"] or 0

			Character:SetAttribute(StatName .. "_XP", XP)
			Character:SetAttribute(StatName .. "_Stars", Stars)
			Character:SetAttribute(StatName .. "_Points", Points)
		end
	end

	return self
end

function TrainingComponent.StartTraining(self: Self, TrainingType: string)
	self.CurrentTraining = TrainingType
end

function TrainingComponent.StopTraining(self: Self)
	self.CurrentTraining = nil
end

function TrainingComponent.ProcessTraining(self: Self, _DeltaTime: number)
	if not self.CurrentTraining then
		return
	end
end

function TrainingComponent.GrantStatGain(self: Self, StatName: string, Amount: number, _FatigueGainOverride: number?)
	if Amount <= 0 then
		return
	end

	local FinalAmount = Amount
	local Sweat = self.Entity:GetComponent("Sweat") :: any
	if Sweat then
		FinalAmount = Amount * Sweat:GetStatGainMultiplier()
	end

	ProgressionSystem.AwardTrainingXP(self.PlayerData, StatName, FinalAmount, self.Entity)

	local Character = self.Entity.Character
	if Character then
		local XPValue = self.PlayerData.Stats[StatName .. "_XP"]
		Character:SetAttribute(StatName .. "_XP", XPValue)

		local Points = self.PlayerData.Stats[StatName .. "_Points"]
		Character:SetAttribute(StatName .. "_Points", Points)
	end
end

function TrainingComponent.CanTrain(self: Self): boolean
	local BodyFatigue = self.Entity:GetComponent("BodyFatigue") :: any
	if not BodyFatigue then
		return true
	end

	return BodyFatigue:CanGainStats()
end

function TrainingComponent.AllocateStatPoint(self: Self, StatName: string): boolean
	local Success, ErrorMessage = StatSystem.AllocateStar(self.PlayerData, StatName)

	if not Success then
		warn("Failed to allocate star:", ErrorMessage)
		return false
	end

	local NewStars = self.PlayerData.Stats[StatName .. "_Stars"]
	local BaseValue = StatDefaults[StatName] or 0
	local NewStatValue = StatSystem.CalculateStatValue(BaseValue, NewStars, StatName)

	self.Entity.Stats:SetStat(StatName, NewStatValue)

	local Character = self.Entity.Character
	if Character then
		Character:SetAttribute(StatName .. "_Stars", NewStars)
		Character:SetAttribute(StatName .. "_Points", self.PlayerData.Stats[StatName .. "_Points"])
	end

	return true
end

function TrainingComponent.GetTotalAllocatedStars(self: Self): number
	return StatSystem.GetTotalAllocatedStars(self.PlayerData)
end

function TrainingComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return TrainingComponent