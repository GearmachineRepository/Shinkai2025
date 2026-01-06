--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local StaminaBalance = require(Shared.Config.Balance.CharacterBalance)

local Player = Players.LocalPlayer

local DOUBLE_TAP_WINDOW_SECONDS = 0.3

local LastWPressTime = 0
local IsInSprintMode = false
local CurrentSprintType = "run"
local SavedSprintType = "run"
local LastSprintEndTime = 0
local SprintIntentActive = false

local ClientSprintHandler = {}

local function GetCharacter(): Model?
	return Player.Character
end

local function IsExhausted(): boolean
	local Character = GetCharacter()
	if not Character then
		return true
	end
	return Character:GetAttribute("Exhausted") == true
end

local function IsOnSprintCooldown(): boolean
	local CurrentTime = os.clock()
	local CooldownDuration = StaminaBalance.Sprint.CooldownSeconds
	return (CurrentTime - LastSprintEndTime) < CooldownDuration
end

function ClientSprintHandler.CanStartSprint(): boolean
	if IsExhausted() then
		return false
	end

	if IsOnSprintCooldown() then
		return false
	end

	return true
end

function ClientSprintHandler.IsSprintIntentActive(): boolean
	return SprintIntentActive
end

function ClientSprintHandler.IsInSprintMode(): boolean
	return IsInSprintMode
end

function ClientSprintHandler.SetSprintIntent(Active: boolean)
	SprintIntentActive = Active
end

function ClientSprintHandler.StartSprint(): boolean
	if not ClientSprintHandler.CanStartSprint() then
		return false
	end

	local Character = GetCharacter()
	if not Character then
		return false
	end

	IsInSprintMode = true
	Character:SetAttribute("PreferredSprintMode", SavedSprintType)
	Packets.MovementStateChanged:Fire(SavedSprintType)
	return true
end

function ClientSprintHandler.StopSprint()
	if not IsInSprintMode then
		return
	end

	LastSprintEndTime = os.clock()
	IsInSprintMode = false
	Packets.MovementStateChanged:Fire("walk")
end

function ClientSprintHandler.ToggleSprintType()
	if not IsInSprintMode then
		return
	end

	if CurrentSprintType == "run" then
		CurrentSprintType = "jog"
		SavedSprintType = "jog"
	else
		CurrentSprintType = "run"
		SavedSprintType = "run"
	end

	local Character = GetCharacter()
	if Character then
		Character:SetAttribute("PreferredSprintMode", SavedSprintType)
	end

	Packets.MovementStateChanged:Fire(SavedSprintType)
end

function ClientSprintHandler.OnWPress(): boolean
	local CurrentTime = os.clock()
	local IsDoubleTap = (CurrentTime - LastWPressTime) <= DOUBLE_TAP_WINDOW_SECONDS
	LastWPressTime = CurrentTime

	if not IsDoubleTap then
		return false
	end

	SprintIntentActive = true
	return true
end

function ClientSprintHandler.OnWRelease()
	SprintIntentActive = false
	ClientSprintHandler.StopSprint()
end

function ClientSprintHandler.SyncFromServer(MovementMode: string)
	if MovementMode == "walk" then
		if IsInSprintMode then
			LastSprintEndTime = os.clock()
		end
		IsInSprintMode = false
	elseif MovementMode == "jog" then
		IsInSprintMode = true
		CurrentSprintType = "jog"
	elseif MovementMode == "run" then
		IsInSprintMode = true
		CurrentSprintType = "run"
	end
end

function ClientSprintHandler.Reset()
	IsInSprintMode = false
	LastSprintEndTime = 0
	LastWPressTime = 0
	SprintIntentActive = false

	local Character = GetCharacter()
	if Character then
		if not Character:GetAttribute("PreferredSprintMode") then
			Character:SetAttribute("PreferredSprintMode", SavedSprintType)
		else
			SavedSprintType = Character:GetAttribute("PreferredSprintMode") :: string
			CurrentSprintType = SavedSprintType
		end
	end
end

return ClientSprintHandler