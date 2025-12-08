--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterLoader = require(Server.Entity.CharacterLoader)
local CharacterController = require(Server.Entity.Core.CharacterController)
local PlayerDataTemplate = require(Shared.Configurations.Data.PlayerDataTemplate)
local DataModule = require(Server.DataModule)

Players.PlayerAdded:Connect(function(Player: Player)
	local PlayerData = DataModule.LoadData(Player)
	if not PlayerData then
		PlayerData = table.clone(PlayerDataTemplate)
	end

	CharacterLoader.LoadPlayer(Player, PlayerData)
end)

Players.PlayerRemoving:Connect(function(Player)
	if Player.Character then
		local Controller = CharacterController.Get(Player.Character)
		if Controller then
			Controller:Destroy()
		end
	end
end)