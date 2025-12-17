--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerDataTemplate = require(Shared.Configurations.Data.PlayerDataTemplate)
local UpdateService = require(Shared.Networking.UpdateService)
local TableUtil = require(Shared.Utils.TableUtil)
local DebugLogger = require(Shared.Debug.DebugLogger)

local AUTOSAVE_INTERVAL = 60

local DataModule = {}
local PlayerDataCache: { [Player]: any } = {}
local AutosaveConnections: { [Player]: RBXScriptConnection } = {}

function DataModule.LoadData(Player: Player): any
	if PlayerDataCache[Player] then
		DebugLogger.Info("DataModule", "Loaded cached data for: %s", Player.Name)
		return PlayerDataCache[Player]
	end

	local NewData = TableUtil.DeepCopy(PlayerDataTemplate)
	PlayerDataCache[Player] = NewData

	DebugLogger.Info("DataModule", "Created new data for: %s", Player.Name)
	return NewData
end

function DataModule.GetData(Player: Player): any?
	return PlayerDataCache[Player]
end

function DataModule.SaveData(Player: Player)
	local Data = PlayerDataCache[Player]
	if not Data then
		DebugLogger.Warning("DataModule", "No data to save for: %s", Player.Name)
		return
	end

	DebugLogger.Info("DataModule", "Saved data for: %s", Player.Name)
end

function DataModule.StartAutosave(Player: Player)
	if AutosaveConnections[Player] then
		DebugLogger.Warning("DataModule", "Autosave already running for: %s", Player.Name)
		return
	end

	local LastSave = tick()

	AutosaveConnections[Player] = UpdateService.Register(function()
		if tick() - LastSave >= AUTOSAVE_INTERVAL then
			DataModule.SaveData(Player)
			LastSave = tick()
		end
	end, 0.10)

	DebugLogger.Info("DataModule", "Started autosave for: %s", Player.Name)
end

function DataModule.StopAutosave(Player: Player)
	if AutosaveConnections[Player] then
		AutosaveConnections[Player]:Disconnect()
		AutosaveConnections[Player] = nil
		DebugLogger.Info("DataModule", "Stopped autosave for: %s", Player.Name)
	end
end

function DataModule.RemoveData(Player: Player)
	DataModule.StopAutosave(Player)

	if PlayerDataCache[Player] then
		PlayerDataCache[Player] = nil
		DebugLogger.Info("DataModule", "Removed data for: %s", Player.Name)
	end
end

Players.PlayerRemoving:Connect(function(Player: Player)
	DataModule.SaveData(Player)
	DataModule.RemoveData(Player)
end)

return DataModule
