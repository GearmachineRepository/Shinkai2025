--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)
local ActionValidator = require(Shared.Utils.ActionValidator)

local VALID_MOVEMENT_MODES = {
	walk = true,
	jog = true,
	run = true,
}

local MODE_TO_ACTION = {
	jog = "Jog",
	run = "Run",
}

Packets.MovementStateChanged.OnServerEvent:Connect(function(Player: Player, MovementMode: string)
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

	if MovementMode == "walk" then
		Character:SetAttribute("MovementMode", "walk")
		return
	end

	local ActionName = MODE_TO_ACTION[MovementMode]
	if ActionName then
		local CanPerform, _Reason = ActionValidator.CanPerform(Entity.States, ActionName)
		if not CanPerform then
			Character:SetAttribute("MovementMode", "walk")
			return
		end
	end

	local Stamina = Entity:GetComponent("Stamina")
	if not Stamina then
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
	end
end)