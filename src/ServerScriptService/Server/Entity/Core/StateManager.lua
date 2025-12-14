--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local EventTypes = require(Shared.Configurations.Enums.EventTypes)
local Signal = require(Shared.Packages.Signal)

local StateManager = {}
StateManager.__index = StateManager

export type StateChangedCallback = (IsActive: boolean) -> ()

export type CallbackConnection = {
	Disconnect: (self: CallbackConnection) -> (),
	Connected: boolean,
}

export type StateManager = typeof(setmetatable(
	{} :: {
		Character: Model,
		States: { [string]: boolean },
		Events: { [string]: any },

		CallbackIdCounter: number,
		CallbacksByState: { [string]: { [number]: StateChangedCallback } },
	},
	StateManager
))

function StateManager.new(Character: Model): StateManager
	local self = setmetatable({
		Character = Character,
		States = {},
		Events = {},

		CallbackIdCounter = 0,
		CallbacksByState = {},
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

	local CallbackTable = self.CallbacksByState[StateName]
	if not CallbackTable or not next(CallbackTable) then
		return
	end

	for _, Callback in CallbackTable do
		task.defer(Callback, Value)
	end
end

function StateManager:OnStateChanged(StateName: string, Callback: StateChangedCallback): CallbackConnection
	local StateCallbacks = self.CallbacksByState[StateName]
	if not StateCallbacks then
		StateCallbacks = {}
		self.CallbacksByState[StateName] = StateCallbacks
	end

	self.CallbackIdCounter += 1
	local CallbackId = self.CallbackIdCounter
	StateCallbacks[CallbackId] = Callback

	local Connection = {
		Connected = true,
		Disconnect = nil :: any,
	}

	function Connection.Disconnect()
		if not Connection.Connected then
			return
		end

		Connection.Connected = false

		local CallbacksForState = self.CallbacksByState[StateName]
		if CallbacksForState then
			CallbacksForState[CallbackId] = nil
		end
	end

	return Connection :: CallbackConnection
end

function StateManager:FireEvent(EventName: string, EventData: any?)
	local Event = self.Events[EventName]
	if Event then
		Event:Fire(EventData)
	end
end

function StateManager:OnEvent(EventName: string, Callback: (EventData: any?) -> ())
	local Event = self.Events[EventName]
	if not Event then
		return nil
	end

	return Event:Connect(Callback)
end

function StateManager:Destroy()
	for _, Event in self.Events do
		if Event.DisconnectAll then
			Event:DisconnectAll()
		end
	end

	table.clear(self.States)
	table.clear(self.Events)
	table.clear(self.CallbacksByState)
end

return StateManager
