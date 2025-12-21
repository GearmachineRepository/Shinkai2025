--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local CallbackRegistry = require(Server.Framework.Utilities.CallbackRegistry)

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

    for _, StateName in pairs(StateTypes) do
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

    local ReplicationMode = StateTypes.GetReplicationMode(StateName)

    if ReplicationMode ~= "LocalOnly" and self.Entity.Character then
        self.Entity.Character:SetAttribute(StateName, Value)
    end

    EventBus.Publish(EntityEvents.STATE_CHANGED, {
        Entity = self.Entity,
        Character = self.Entity.Character,
        StateName = StateName,
        Value = Value,
        ReplicationMode = ReplicationMode,
    })

    CallbackRegistry.Fire(StateName, Value)
end

function StateComponent:OnStateChanged(StateName: string, Callback: (Value: boolean) -> ()): CallbackConnection
    return CallbackRegistry.Register(StateName, Callback)
end

function StateComponent:Destroy()
    if self.Entity.Character then
        CallbackRegistry.ClearScope(self.Entity.Character)
    end

    table.clear(self.States)
end

return StateComponent