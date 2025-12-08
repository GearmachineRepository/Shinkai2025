--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerDataTemplate = require(Shared.Configurations.Data.PlayerDataTemplate)

local AUTOSAVE_INTERVAL = 60 -- 1 minute

local DataModule = {}
local PlayerDataCache: {[Player]: any} = {}
local AutosaveConnections: {[Player]: RBXScriptConnection} = {}

function DataModule.LoadData(Player: Player): any
	if PlayerDataCache[Player] then
		return PlayerDataCache[Player]
	end

	local NewData = table.clone(PlayerDataTemplate)
	PlayerDataCache[Player] = NewData

	print("[DataModule] Loaded data for", Player.Name)
	return NewData
end

function DataModule.GetData(Player: Player): any?
	return PlayerDataCache[Player]
end

function DataModule.SaveData(Player: Player)
	local Data = PlayerDataCache[Player]
	if not Data then
		warn("[DataModule] No data to save for", Player.Name)
		return
	end

	print("[DataModule] Saved data for", Player.Name)
end

function DataModule.StartAutosave(Player: Player)
	if AutosaveConnections[Player] then
		return
	end

	local LastSave = os.clock()

	AutosaveConnections[Player] = game:GetService("RunService").Heartbeat:Connect(function()
		if os.clock() - LastSave >= AUTOSAVE_INTERVAL then
			DataModule.SaveData(Player)
			LastSave = os.clock()
		end
	end)

	print("[DataModule] Started autosave for", Player.Name)
end

function DataModule.StopAutosave(Player: Player)
	if AutosaveConnections[Player] then
		AutosaveConnections[Player]:Disconnect()
		AutosaveConnections[Player] = nil
		print("[DataModule] Stopped autosave for", Player.Name)
	end
end

function DataModule.RemoveData(Player: Player)
	DataModule.StopAutosave(Player)
	warn(PlayerDataCache[Player])
	PlayerDataCache[Player] = nil
	print("[DataModule] Removed data for", Player.Name)
end

Players.PlayerRemoving:Connect(function(Player)
	DataModule.SaveData(Player)
	DataModule.RemoveData(Player)
end)

return DataModule