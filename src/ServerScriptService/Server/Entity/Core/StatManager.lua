--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Formulas = require(Shared.General.Formulas)
local DebugLogger = require(Shared.Debug.DebugLogger)

local StatManager = {}
StatManager.__index = StatManager

export type StatChangedCallback = (NewValue: number, OldValue: number) -> ()

export type CallbackConnection = {
	Disconnect: (self: CallbackConnection) -> (),
	Connected: boolean,
}

export type StatManager = typeof(setmetatable(
	{} :: {
		Character: Model,
		Stats: { [string]: number },
		PlayerData: any,

		CallbackIdCounter: number,
		CallbacksByStat: { [string]: { [number]: StatChangedCallback } },
	},
	StatManager
))

local UPDATE_THRESHOLD = 0.001

function StatManager.new(Character: Model, PlayerData: any?): StatManager
	local self = setmetatable({
		Character = Character,
		PlayerData = PlayerData,
		Stats = {},

		CallbackIdCounter = 0,
		CallbacksByStat = {},
	}, StatManager)

	for StatName, DefaultValue in StatBalance.Defaults do
		if PlayerData and PlayerData.Stats and PlayerData.Stats[StatName] ~= nil then
			self.Stats[StatName] = PlayerData.Stats[StatName]
		else
			self.Stats[StatName] = DefaultValue
		end
	end

	self:InitializeAttributes()
	return self
end

function StatManager:InitializeAttributes()
	if not self.Character then
		DebugLogger.Warning("StatManager", "Cannot initialize attributes - no character")
		return
	end

	for StatName, Value in self.Stats do
		self.Character:SetAttribute(StatName, Value)
	end
end

function StatManager:GetStat(StatName: string): number
	return self.Stats[StatName] or 0
end

function StatManager:ModifyStat(StatName: string, Delta: number)
	local Current = self:GetStat(StatName)
	self:SetStat(StatName, Current + Delta)
end

function StatManager:SetStat(StatName: string, Value: number)
	local OldValue = self.Stats[StatName] or 0

	local ShouldUpdate = if StatName == StatTypes.BODY_FATIGUE
		then OldValue ~= Value
		else not Formulas.IsNearlyEqual(OldValue, Value, UPDATE_THRESHOLD)

	if not ShouldUpdate then
		return
	end

	self.Stats[StatName] = Value

	if self.Character then
		self.Character:SetAttribute(StatName, Value)
	end

	if self.PlayerData and self.PlayerData.Stats and self.PlayerData.Stats[StatName] ~= nil then
		self.PlayerData.Stats[StatName] = Value
	end

	local CallbackTable = self.CallbacksByStat[StatName]
	if not CallbackTable or not next(CallbackTable) then
		return
	end

	for _, Callback in CallbackTable do
		task.defer(Callback, Value, OldValue)
	end
end

function StatManager:OnStatChanged(StatName: string, Callback: StatChangedCallback): CallbackConnection
	local StatCallbacks = self.CallbacksByStat[StatName]
	if not StatCallbacks then
		StatCallbacks = {}
		self.CallbacksByStat[StatName] = StatCallbacks
	end

	self.CallbackIdCounter += 1
	local CallbackId = self.CallbackIdCounter
	StatCallbacks[CallbackId] = Callback

	local Connection = {
		Connected = true,
		Disconnect = nil :: any,
	}

	function Connection.Disconnect()
		if not Connection.Connected then
			return
		end

		Connection.Connected = false

		local CallbacksForStat = self.CallbacksByStat[StatName]
		if CallbacksForStat then
			CallbacksForStat[CallbackId] = nil
		end
	end

	return Connection :: CallbackConnection
end

function StatManager:GetAllStats(): { [string]: number }
	return table.clone(self.Stats)
end

function StatManager:Destroy()
	DebugLogger.Info("StatManager", "Destroying StatManager")
	table.clear(self.Stats)
	table.clear(self.CallbacksByStat)
end

return StatManager
