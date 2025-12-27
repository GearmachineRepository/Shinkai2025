--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local VALID_MOVEMENT_MODES = {
	walk = true,
	jog = true,
	run = true,
}

local function ValidateMovementMode(Mode: string): boolean
	return VALID_MOVEMENT_MODES[Mode] == true
end

Packets.MovementStateChanged.OnServerEvent:Connect(function(Player: Player, MovementMode: string)
	if not ValidateMovementMode(MovementMode) then
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

	if Entity.States:GetState(StateTypes.ATTACKING) and (MovementMode == "jog" or MovementMode == "run") then
		Character:SetAttribute("MovementMode", "walk")
		return
	end

	local Stamina = Entity:GetComponent("Stamina")
	if not Stamina then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	if MovementMode == "jog" then
		if Stamina:CanJog() then
			Character:SetAttribute("MovementMode", "jog")
		else
			Character:SetAttribute("MovementMode", "walk")
		end
	elseif MovementMode == "run" then
		if Stamina:CanSprint() then
			Character:SetAttribute("MovementMode", "run")
		else
			Character:SetAttribute("MovementMode", "walk")
		end
	elseif MovementMode == "walk" then
		Character:SetAttribute("MovementMode", "walk")
	end
end)