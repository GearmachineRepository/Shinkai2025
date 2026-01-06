--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlayerDataTemplate = require(Shared.Config.Data.PlayerDataTemplate)
local UpdateService = require(Shared.Utility.UpdateService)
local TableUtil = require(Shared.Utility.TableUtil)

local AUTOSAVE_INTERVAL: number = 60
local AUTOSAVE_RATE_SECONDS: number = 1 / 2

local DataModule = {}

local PlayerDataCache: { [Player]: unknown } = {}
local AutosaveHandles: { [Player]: UpdateService.Handle } = {}

function DataModule.LoadData(Player: Player): unknown
	local ExistingData = PlayerDataCache[Player]
	if ExistingData ~= nil then
		return ExistingData
	end

	local NewData = TableUtil.DeepCopy(PlayerDataTemplate)
	PlayerDataCache[Player] = NewData

	return NewData
end

function DataModule.GetData(Player: Player): unknown?
	return PlayerDataCache[Player]
end

function DataModule.SaveData(Player: Player)
	local Data = PlayerDataCache[Player]
	if Data == nil then
		return
	end

	-- Persist Data here
end

function DataModule.StartAutosave(Player: Player)
	if AutosaveHandles[Player] ~= nil then
		return
	end

	local LastSave: number = tick()

	local AutosaveHandle: UpdateService.Handle = UpdateService.Register(function()
		if tick() - LastSave >= AUTOSAVE_INTERVAL then
			DataModule.SaveData(Player)
			LastSave = tick()
		end
	end, AUTOSAVE_RATE_SECONDS)

	AutosaveHandles[Player] = AutosaveHandle
end

function DataModule.StopAutosave(Player: Player)
	local AutosaveHandle = AutosaveHandles[Player]
	if AutosaveHandle == nil then
		return
	end

	UpdateService.Disconnect(AutosaveHandle)
	AutosaveHandles[Player] = nil
end

function DataModule.RemoveData(Player: Player)
	DataModule.StopAutosave(Player)
	PlayerDataCache[Player] = nil
end

Players.PlayerRemoving:Connect(function(Player: Player)
	DataModule.SaveData(Player)
	DataModule.RemoveData(Player)
end)

return DataModule
