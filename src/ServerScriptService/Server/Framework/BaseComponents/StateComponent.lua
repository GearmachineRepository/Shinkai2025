--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local CallbackRegistry = require(Server.Framework.Utilities.CallbackRegistry)
local DebugLogger = require(Shared.Debug.DebugLogger)

export type CallbackConnection = {
	Disconnect: () -> (),
	Connected: boolean,
}

export type StateComponent = {
	Entity: any,

	GetState: (self: StateComponent, StateName: string) -> boolean,
	SetState: (self: StateComponent, StateName: string, Value: boolean) -> (),
	OnStateChanged: (self: StateComponent, StateName: string, Callback: (Value: boolean) -> ()) -> CallbackConnection,
	Destroy: (self: StateComponent) -> (),
}

type StateComponentInternal = StateComponent & {
	States: { [string]: boolean },
}

local StateComponent = {}
StateComponent.__index = StateComponent

function StateComponent.new(Entity: any): StateComponent
	local self: StateComponentInternal = setmetatable({
		Entity = Entity,
		States = {},
	}, StateComponent) :: any

	for _, StateName in StateTypes do
		self.States[StateName] = false
	end

	return self
end

function StateComponent:GetState(StateName: string): boolean
	return self.States[StateName] or false
end

function StateComponent:SetState(StateName: string, Value: boolean)
	if self.States[StateName] == Value then
		return
	end

	self.States[StateName] = Value

	if self.Entity.Character then
		self.Entity.Character:SetAttribute(StateName, Value)
	end

	EventBus.Publish(EntityEvents.STATE_CHANGED, {
		Entity = self.Entity,
		Character = self.Entity.Character,
		StateName = StateName,
		Value = Value,
	})

	CallbackRegistry.Fire(StateName, Value)
end

function StateComponent:Destroy()
	DebugLogger.Info("StateComponent", "Destroying StateComponent for: %s", self.Entity.Character.Name)

	if self.Entity.Character then
		CallbackRegistry.ClearScope(self.Entity.Character)
	end

	table.clear(self.States)

	DebugLogger.Info("StateComponent", "StateComponent destroyed for: %s", self.Entity.Character.Name)
end

return StateComponent
