--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatBalance = require(Shared.Configurations.Balance.StatBalance)

local StatManager = {}
StatManager.__index = StatManager

export type StatManager = typeof(setmetatable({} :: {
	Character: Model,
	Stats: {[string]: number},
	StatChangedCallbacks: {[string]: {(NewValue: number, OldValue: number) -> ()}},
}, StatManager))

function StatManager.new(Character: Model, PlayerData: any?): StatManager
	local self = setmetatable({
		Character = Character,
		PlayerData = PlayerData,
		Stats = {},
		StatChangedCallbacks = {},
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
		return
	end

	for StatName, Value in self.Stats do
		self.Character:SetAttribute(StatName, Value)
	end
end

function StatManager:GetStat(StatName: string): number
	return self.Stats[StatName] or 0
end

function StatManager:SetStat(StatName: string, Value: number)
	local OldValue = self.Stats[StatName] or 0
	self.Stats[StatName] = Value

	if self.Character then
		self.Character:SetAttribute(StatName, Value)
	end

	if self.PlayerData and self.PlayerData.Stats and self.PlayerData.Stats[StatName] ~= nil then
		self.PlayerData.Stats[StatName] = Value
	end

	local Callbacks = self.StatChangedCallbacks[StatName]
	if Callbacks then
		for _, Callback in Callbacks do
			task.spawn(Callback, Value, OldValue)
		end
	end
end

function StatManager:ModifyStat(StatName: string, Delta: number)
	local Current = self:GetStat(StatName)
	self:SetStat(StatName, Current + Delta)
end

function StatManager:OnStatChanged(StatName: string, Callback: (NewValue: number, OldValue: number) -> ())
	if not self.StatChangedCallbacks[StatName] then
		self.StatChangedCallbacks[StatName] = {}
	end

	table.insert(self.StatChangedCallbacks[StatName], Callback)
end

function StatManager:GetAllStats(): {[string]: number}
	return table.clone(self.Stats)
end

function StatManager:Destroy()

end

return StatManager