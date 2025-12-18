--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Entity = require(Server.Framework.Core.Entity)
local Packets = require(Shared.Networking.Packets)

local MAX_DIRECTION_MAGNITUDE = 1.1
local MIN_DIRECTION_MAGNITUDE = 0.9

local function ValidateDirection(Direction: Vector3): boolean
	if typeof(Direction) ~= "Vector3" then
		return false
	end

	local Magnitude = Direction.Magnitude
	if Magnitude < MIN_DIRECTION_MAGNITUDE or Magnitude > MAX_DIRECTION_MAGNITUDE then
		return false
	end

	if math.abs(Direction.Y) > 0.1 then
		return false
	end

	return true
end

local function ValidateActionData(ActionName: string, ActionData: any?): boolean
	if ActionName == "Dash" then
		if not ActionData or not ActionData.Direction then
			return false
		end
		return ValidateDirection(ActionData.Direction)
	end

	return true
end

Packets.PerformAction.OnServerEvent:Connect(function(Player: Player, ActionName: string, ActionData: any?)
	if typeof(ActionName) ~= "string" then
		return
	end

	if not ValidateActionData(ActionName, ActionData) then
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
