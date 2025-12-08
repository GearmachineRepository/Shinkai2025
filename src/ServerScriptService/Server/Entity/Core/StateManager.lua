--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local EventTypes = require(Shared.Configurations.Enums.EventTypes)
local Signal = require(Shared.Packages.GoodSignal)

local StateManager = {}
StateManager.__index = StateManager

export type StateManager = typeof(setmetatable({} :: {
	Character: Model,
	States: {[string]: boolean},
	Events: {[string]: any},
	StateChangedCallbacks: {[string]: {(IsActive: boolean) -> ()}},
}, StateManager))

function StateManager.new(Character: Model): StateManager
	local self = setmetatable({
		Character = Character,
		States = {},
		Events = {},
		StateChangedCallbacks = {},
	}, StateManager)

	for _, StateName in StateTypes do
		self.States[StateName] = false
	end

	for _, EventName in EventTypes do
		self.Events[EventName] = Signal.new()
	end

	return self
end

function StateManager:GetState(StateName: string): boolean
	return self.States[StateName] or false
end

function StateManager:SetState(StateName: string, Value: boolean)
	if self.States[StateName] == Value then
		return
	end

	self.States[StateName] = Value

	if self.Character then
		self.Character:SetAttribute(StateName, Value)
	end

	local Callbacks = self.StateChangedCallbacks[StateName]
	if Callbacks then
		for _, Callback in Callbacks do
			task.spawn(Callback, Value)
		end
	end
end

function StateManager:OnStateChanged(StateName: string, Callback: (IsActive: boolean) -> ())
	if not self.StateChangedCallbacks[StateName] then
		self.StateChangedCallbacks[StateName] = {}
	end

	table.insert(self.StateChangedCallbacks[StateName], Callback)
end

function StateManager:FireEvent(EventName: string, EventData: any?)
	local Event = self.Events[EventName]
	if Event then
		Event:Fire(EventData)
	end
end

function StateManager:OnEvent(EventName: string, Callback: (EventData: any?) -> ())
	local Event = self.Events[EventName]
	if Event then
		return Event:Connect(Callback)
	end
end

function StateManager:Destroy()
	for _, Event in self.Events do
		if Event.DisconnectAll then
			Event:DisconnectAll()
		end
	end

	table.clear(self.States)
	table.clear(self.Events)
	table.clear(self.StateChangedCallbacks)
end

return StateManager