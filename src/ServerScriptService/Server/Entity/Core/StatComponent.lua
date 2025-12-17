--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Formulas = require(Shared.General.Formulas)
local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local CallbackRegistry = require(Server.Core.CallbackRegistry)

export type CallbackConnection = {
	Disconnect: () -> (),
	Connected: boolean,
}

export type StatComponent = {
	Entity: any,

	GetStat: (self: StatComponent, StatName: string) -> number,
	SetStat: (self: StatComponent, StatName: string, Value: number) -> (),
	ModifyStat: (self: StatComponent, StatName: string, Delta: number) -> (),
	GetAllStats: (self: StatComponent) -> { [string]: number },
	OnStatChanged: (
		self: StatComponent,
		StatName: string,
		Callback: (NewValue: number, OldValue: number) -> ()
	) -> CallbackConnection,
	Destroy: (self: StatComponent) -> (),
}

type StatComponentInternal = StatComponent & {
	Stats: { [string]: number },
	PlayerData: any?,
}

local StatComponent = {}
StatComponent.__index = StatComponent

local UPDATE_THRESHOLD = 0.001

function StatComponent.new(Entity: any, PlayerData: any?): StatComponent
	local self: StatComponentInternal = setmetatable({
		Entity = Entity,
		PlayerData = PlayerData,
		Stats = {},
	}, StatComponent) :: any

	for StatName, DefaultValue in StatBalance.Defaults do
		if PlayerData and PlayerData.Stats and PlayerData.Stats[StatName] ~= nil then
			if StatName == StatTypes.STAMINA then
				self.Stats[StatName] = PlayerData.Stats[StatTypes.MAX_STAMINA] or DefaultValue
			else
				self.Stats[StatName] = PlayerData.Stats[StatName]
			end
		else
			self.Stats[StatName] = DefaultValue
		end
	end

	self:InitializeAttributes()
	return self
end

function StatComponent:InitializeAttributes()
	if not self.Entity.Character then
		return
	end

	for StatName, Value in self.Stats do
		self.Entity.Character:SetAttribute(StatName, Value)
	end
end

function StatComponent:GetStat(StatName: string): number
	return self.Stats[StatName] or 0
end

function StatComponent:ModifyStat(StatName: string, Delta: number)
	local Current = self:GetStat(StatName)
	self:SetStat(StatName, Current + Delta)
end

function StatComponent:SetStat(StatName: string, Value: number)
	local OldValue = self.Stats[StatName] or 0

	local ShouldUpdate = if StatName == StatTypes.BODY_FATIGUE
		then OldValue ~= Value
		else not Formulas.IsNearlyEqual(OldValue, Value, UPDATE_THRESHOLD)

	if not ShouldUpdate then
		return
	end

	self.Stats[StatName] = Value

	if self.Entity.Character then
		self.Entity.Character:SetAttribute(StatName, Value)
	end

	if self.PlayerData and self.PlayerData.Stats and self.PlayerData.Stats[StatName] ~= nil then
		self.PlayerData.Stats[StatName] = Value
	end

	EventBus.Publish(EntityEvents.STAT_CHANGED, {
		Entity = self.Entity,
		Character = self.Entity.Character,
		StatName = StatName,
		NewValue = Value,
		OldValue = OldValue,
	})

	CallbackRegistry.Fire("StatChanged:" .. StatName, Value, OldValue)
end

function StatComponent:OnStatChanged(
	StatName: string,
	Callback: (NewValue: number, OldValue: number) -> ()
): CallbackConnection
	return CallbackRegistry.Register("StatChanged:" .. StatName, Callback, self.Entity.Character)
end

function StatComponent:GetAllStats(): { [string]: number }
	return table.clone(self.Stats)
end

function StatComponent:Destroy()
	if self.Entity.Character then
		CallbackRegistry.ClearScope(self.Entity.Character)
	end
	table.clear(self.Stats)
end

return StatComponent
