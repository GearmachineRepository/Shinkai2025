--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local ProgressionSystem = require(Server.Game.Systems.ProgressionSystem)
local StatTypes = require(Shared.Config.Enums.StatTypes)
local FatigueBalance = require(Shared.Config.Body.FatigueBalance)

local BodyFatigueComponent = {}
BodyFatigueComponent.__index = BodyFatigueComponent

BodyFatigueComponent.ComponentName = "BodyFatigue"
BodyFatigueComponent.Dependencies = { "Stats" }
BodyFatigueComponent.UpdateRate = 1

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	PlayerData: any,
}

function BodyFatigueComponent.new(Entity: Types.Entity, Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		PlayerData = Context.Data,
	}, BodyFatigueComponent) :: any

	return self
end

function BodyFatigueComponent.Update(self: Self, DeltaTime: number)
	local CompatShim = {
		StatManager = self.Entity.Stats,
		IsPlayer = self.Entity.Player,
	}

	ProgressionSystem.ProcessHunger(self.PlayerData, DeltaTime, CompatShim)
	ProgressionSystem.ProcessFat(self.PlayerData, DeltaTime, CompatShim)
end

function BodyFatigueComponent.AddFatigueFromStatGain(self: Self, FatigueGain: number)
	if FatigueGain < FatigueBalance.Updates.Threshold then
		return
	end

	local CurrentFatigue = self.Entity.Stats:GetStat(StatTypes.BODY_FATIGUE)
	local MaxFatigue = self.Entity.Stats:GetStat(StatTypes.MAX_BODY_FATIGUE)

	local NewFatigue = math.min(MaxFatigue, CurrentFatigue + FatigueGain)

	self.Entity.Stats:SetStat(StatTypes.BODY_FATIGUE, NewFatigue)
end

function BodyFatigueComponent.CanGainStats(self: Self): boolean
	return ProgressionSystem.CanTrain(self.PlayerData)
end

function BodyFatigueComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return BodyFatigueComponent