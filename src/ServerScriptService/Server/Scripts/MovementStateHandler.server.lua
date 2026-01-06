--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)

local VALID_MOVEMENT_MODES = {
	walk = true,
	jog = true,
	run = true,
}

Packets.MovementStateChanged.OnServerEvent:Connect(function(Player: Player, MovementMode: string)
	if type(MovementMode) ~= "string" then
		return
	end

	if not VALID_MOVEMENT_MODES[MovementMode] then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local Entity = Ensemble.GetEntity(Character)
	if not Entity then
		return
	end

	local Movement = Entity:GetComponent("Movement")
	if not Movement then
		return
	end

	local IsValid = Movement:ValidateMovementMode(MovementMode)

	if IsValid then
		Character:SetAttribute("MovementMode", MovementMode)
	else
		Character:SetAttribute("MovementMode", "walk")
	end
end)