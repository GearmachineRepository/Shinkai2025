--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterController = require(Server.Entity.Core.CharacterController)
local Packets = require(Shared.Networking.Packets)

Packets.MovementStateChanged.OnServerEvent:Connect(function(Player: Player, MovementMode: string)
	local Character = Player.Character
	if not Character then
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller or not Controller.StaminaController then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	if MovementMode == "jog" then
		if Controller.StaminaController:CanJog() then
			Character:SetAttribute("MovementMode", "jog")
		else
			Character:SetAttribute("MovementMode", "walk")
		end
	elseif MovementMode == "run" then
		if Controller.StaminaController:CanSprint() then
			Character:SetAttribute("MovementMode", "run")
		else
			Character:SetAttribute("MovementMode", "walk")
		end
	elseif MovementMode == "walk" then
		Character:SetAttribute("MovementMode", "walk")
	end
end)