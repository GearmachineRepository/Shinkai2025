--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatController = require(script.Parent.Parent.CombatController)

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

--[=[
    STATE HANDLER LIFECYCLE:

    OnEnter(Entity, EventData)
        - Called when state becomes true
        - EventData contains: Entity, Character, StateName, Value, Replication

    OnExit(Entity, EventData)
        - Called when state becomes false

    OnUpdate(Entity, DeltaTime) [optional]
        - Called every frame while state is active
        - Must be registered separately if needed
]=]

local StateTemplate = {}

function StateTemplate.OnEnter(Entity: any, EventData: any)
    CombatController.Replicate("StateEntered", Entity, {
        StateName = EventData.StateName,
    })
end

function StateTemplate.OnExit(Entity: any, EventData: any)
    CombatController.Replicate("StateExited", Entity, {
        StateName = EventData.StateName,
    })
end

return StateTemplate