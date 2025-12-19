--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Entity = require(Server.Framework.Core.Entity)
local Packets = require(Shared.Networking.Packets)
local ActionRegistry = require(Shared.Actions.ActionRegistry)

Packets.PerformAction.OnServerEvent:Connect(function(Player: Player, ActionName: string, ActionData: any?)
	if typeof(ActionName) ~= "string" then
		return
	end

	local Action = ActionRegistry.Get(ActionName)
	if not Action then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Action then
		return
	end

	EntityInstance.Components.Action:PerformAction(ActionName, ActionData)
end)
