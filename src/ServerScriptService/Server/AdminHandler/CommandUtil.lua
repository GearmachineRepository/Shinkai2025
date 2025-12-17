--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterController = require(Server.Entity.Core.CharacterController)
local HookRegistry = require(Server.Entity.Registry.HookRegistry)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)

local CommandUtil = {}

CommandUtil.States = StateTypes
CommandUtil.Stats = StatTypes

function CommandUtil.GetController(Player: Player)
	local Character = Player.Character or workspace:FindFirstChild(Player.Name)

	if not Character then
		warn("No character found for", Player.Name)
		return nil
	end

	local Controller = CharacterController.Get(Character)
	if not Controller then
		warn("Controller not found. Try waiting a moment after spawning.")
		return nil
	end

	return Controller
end

function CommandUtil.GetCharacter(Player: Player): Model?
	return Player.Character or workspace:FindFirstChild(Player.Name)
end

function CommandUtil.GetHook(HookName: string)
	return HookRegistry.Get(HookName)
end

return CommandUtil