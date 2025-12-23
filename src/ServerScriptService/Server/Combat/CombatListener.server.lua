--!strict
-- Server/Combat/CombatListener.server.lua

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local ActionRegistry = require(Server.Combat.ActionRegistry)

local function Initialize()
    local ActionsFolder = Server.Combat.Actions
    ActionRegistry.LoadFolder(ActionsFolder)
end

Packets.PerformAction.OnServerEvent:Connect(function(Player, ActionName, InputData)
    local Character = Player.Character
    if not Character then
        Packets.ActionDenied:FireClient(Player, "No character")
        return
    end

    local Entity = Ensemble.GetEntity(Character)
    if not Entity then
        Packets.ActionDenied:FireClient(Player, "No entity")
        return
    end

    local Success, Reason = ActionExecutor.Execute(Entity, ActionName, InputData)

    if Success then
        Packets.ActionApproved:FireClient(Player, ActionName)
    else
        Packets.ActionDenied:FireClient(Player, Reason or "Failed")
    end
end)

Initialize()