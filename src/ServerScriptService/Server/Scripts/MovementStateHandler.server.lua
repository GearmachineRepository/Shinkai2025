--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Entity = require(Server.Framework.Core.Entity)
local Packets = require(Shared.Networking.Packets)
local DebugLogger = require(Shared.Debug.DebugLogger)

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
		DebugLogger.Warning("MovementStateHandler", "Invalid movement mode from %s: %s", Player.Name, MovementMode)
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Stamina then
		DebugLogger.Warning("MovementStateHandler", "No entity for %s", Player.Name)
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	if MovementMode == "jog" then
		if EntityInstance.Components.Stamina:CanJog() then
			Character:SetAttribute("MovementMode", "jog")
		else
			Character:SetAttribute("MovementMode", "walk")
			DebugLogger.Info("MovementStateHandler", "%s cannot jog - exhausted", Player.Name)
		end
	elseif MovementMode == "run" then
		if EntityInstance.Components.Stamina:CanSprint() then
			Character:SetAttribute("MovementMode", "run")
		else
			Character:SetAttribute("MovementMode", "walk")
			DebugLogger.Info("MovementStateHandler", "%s cannot run - exhausted", Player.Name)
		end
	elseif MovementMode == "walk" then
		Character:SetAttribute("MovementMode", "walk")
	end
end)
