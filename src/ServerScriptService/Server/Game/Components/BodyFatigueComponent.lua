--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProgressionSystem = require(Server.Game.Systems.ProgressionSystem)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Maid = require(Shared.General.Maid)
local FatigueBalance = require(Shared.Configurations.Balance.FatigueBalance)

export type BodyFatigueComponent = {
	Entity: any,
	Update: (self: BodyFatigueComponent, DeltaTime: number) -> (),
	AddFatigueFromStatGain: (self: BodyFatigueComponent, FatigueGain: number) -> (),
	CanGainStats: (self: BodyFatigueComponent) -> boolean,
	Destroy: (self: BodyFatigueComponent) -> (),
}

type BodyFatigueComponentInternal = BodyFatigueComponent & {
	PlayerData: any,
	Maid: Maid.MaidSelf,
	UpdateAccumulator: number,
}

local BodyFatigueComponent = {}
BodyFatigueComponent.__index = BodyFatigueComponent

function BodyFatigueComponent.new(Entity: any, PlayerData: any): BodyFatigueComponent
	local self: BodyFatigueComponentInternal = setmetatable({
		Entity = Entity,
		PlayerData = PlayerData,
		Maid = Maid.new(),
		UpdateAccumulator = 0,
	}, BodyFatigueComponent) :: any

	return self
end

function BodyFatigueComponent:Update(DeltaTime: number)
	self.UpdateAccumulator += DeltaTime

	if self.UpdateAccumulator < FatigueBalance.Updates.UPDATE_INTERVAL then
		return
	end

	local AccumulatedTime = self.UpdateAccumulator
	self.UpdateAccumulator = 0

	local CompatShim = {
		StatManager = self.Entity.Stats,
		IsPlayer = self.Entity.Player,
	}

	ProgressionSystem.ProcessHunger(self.PlayerData, AccumulatedTime, CompatShim)
	ProgressionSystem.ProcessFat(self.PlayerData, AccumulatedTime, CompatShim)
end

function BodyFatigueComponent:AddFatigueFromStatGain(FatigueGain: number)
	if FatigueGain < FatigueBalance.Updates.UPDATE_THRESHOLD then
		return
	end

	local CurrentFatigue = self.Entity.Stats:GetStat(StatTypes.BODY_FATIGUE)
	local MaxFatigue = self.Entity.Stats:GetStat(StatTypes.MAX_BODY_FATIGUE)

	local NewFatigue = math.min(MaxFatigue, CurrentFatigue + FatigueGain)

	self.Entity.Stats:SetStat(StatTypes.BODY_FATIGUE, NewFatigue)
end

function BodyFatigueComponent:CanGainStats(): boolean
	return ProgressionSystem.CanTrain(self.PlayerData)
end

function BodyFatigueComponent:Destroy()
	self.Maid:DoCleaning()
end

return BodyFatigueComponent
