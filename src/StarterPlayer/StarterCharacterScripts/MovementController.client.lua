--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local UpdateService = require(Shared.Networking.UpdateService)
local StaminaBalance = require(Shared.Configurations.Balance.StaminaBalance)

local Player = Players.LocalPlayer
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

local DOUBLE_TAP_WINDOW_SECONDS = 0.5
local STOP_MOVING_THRESHOLD = 0.1
local STOP_MOVING_GRACE_SECONDS = 0.15

local LastWPressTime = 0
local IsInSprintMode = false
local CurrentSprintType = "run"
local SavedSprintType = "run"
local IsWHeld = false
local StopMovingTimeSeconds = 0
local LastSprintEndTime = 0

if not Character:GetAttribute("MovementMode") then
	Character:SetAttribute("MovementMode", "walk")
end

if not Character:GetAttribute("PreferredSprintMode") then
	Character:SetAttribute("PreferredSprintMode", "run")
else
	SavedSprintType = Character:GetAttribute("PreferredSprintMode")
	CurrentSprintType = SavedSprintType
end

local function IsExhausted(): boolean
	return Character:GetAttribute("Exhausted") == true
end

local function IsOnSprintCooldown(): boolean
	local CurrentTime = os.clock()
	local CooldownDuration = StaminaBalance.Sprint.COOLDOWN_SECONDS
	return (CurrentTime - LastSprintEndTime) < CooldownDuration
end

local function CanStartSprint(): boolean
	if IsExhausted() then
		return false
	end

	if IsOnSprintCooldown() then
		return false
	end

	return true
end

local function SetMovementMode(Mode: string)
	if Mode == "walk" then
		if IsInSprintMode then
			LastSprintEndTime = os.clock()
		end
		IsInSprintMode = false
		Packets.MovementStateChanged:Fire("walk")
		return
	end

	if not CanStartSprint() then
		if IsInSprintMode then
			LastSprintEndTime = os.clock()
		end
		IsInSprintMode = false
		Packets.MovementStateChanged:Fire("walk")
		return
	end

	if Mode == "jog" then
		Character:SetAttribute("PreferredSprintMode", "jog")
		IsInSprintMode = true
		CurrentSprintType = "jog"
		SavedSprintType = "jog"
		Packets.MovementStateChanged:Fire("jog")
	elseif Mode == "run" then
		Character:SetAttribute("PreferredSprintMode", "run")
		IsInSprintMode = true
		CurrentSprintType = "run"
		SavedSprintType = "run"
		Packets.MovementStateChanged:Fire("run")
	end
end

local function EnterSprintMode()
	if not IsWHeld then
		return
	end

	if not CanStartSprint() then
		return
	end

	SetMovementMode(SavedSprintType)
end

local function ExitSprintMode()
	if IsInSprintMode then
		SetMovementMode("walk")
	end
end

local function ToggleSprintType()
	if not IsInSprintMode then
		return
	end

	if CurrentSprintType == "run" then
		SetMovementMode("jog")
	else
		SetMovementMode("run")
	end
end

local function OnInputBegan(Input: InputObject, GameProcessedEvent: boolean)
	if GameProcessedEvent then
		return
	end

	if Input.KeyCode == Enum.KeyCode.W then
		IsWHeld = true

		local CurrentTime = os.clock()
		if CurrentTime - LastWPressTime <= DOUBLE_TAP_WINDOW_SECONDS then
			EnterSprintMode()
		end
		LastWPressTime = CurrentTime

	-- Shift-to-sprint (commented out for future use)
	-- elseif Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.RightShift then
	-- 	EnterSprintMode()

	elseif Input.KeyCode == Enum.KeyCode.R then
		ToggleSprintType()
	end
end

local function OnInputEnded(Input: InputObject, GameProcessedEvent: boolean)
	if GameProcessedEvent then
		return
	end

	if Input.KeyCode == Enum.KeyCode.W then
		IsWHeld = false
		if IsInSprintMode then
			ExitSprintMode()
		end

	-- Shift-to-sprint (commented out for future use)
	-- elseif Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.RightShift then
	-- 	if IsInSprintMode then
	-- 		ExitSprintMode()
	-- 	end
	end
end

UserInputService.InputBegan:Connect(OnInputBegan)
UserInputService.InputEnded:Connect(OnInputEnded)

UpdateService.Register(function(DeltaTime: number)
	if not IsInSprintMode then
		StopMovingTimeSeconds = 0
		return
	end

	if Humanoid.MoveDirection.Magnitude < STOP_MOVING_THRESHOLD then
		StopMovingTimeSeconds += DeltaTime
		if StopMovingTimeSeconds >= STOP_MOVING_GRACE_SECONDS then
			StopMovingTimeSeconds = 0
			SetMovementMode("walk")
		end
	else
		StopMovingTimeSeconds = 0
	end
end, 0.10)

Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
	local ServerMode = Character:GetAttribute("MovementMode")

	if ServerMode == "walk" then
		if IsInSprintMode then
			LastSprintEndTime = os.clock()
		end
		IsInSprintMode = false
	elseif ServerMode == "jog" then
		IsInSprintMode = true
		CurrentSprintType = "jog"
	elseif ServerMode == "run" then
		IsInSprintMode = true
		CurrentSprintType = "run"
	end
end)

Player.CharacterAdded:Connect(function(NewCharacter)
	Character = NewCharacter
	Humanoid = NewCharacter:WaitForChild("Humanoid")

	IsInSprintMode = false
	LastSprintEndTime = 0
	StopMovingTimeSeconds = 0

	if not Character:GetAttribute("MovementMode") then
		Character:SetAttribute("MovementMode", "walk")
	end

	if not Character:GetAttribute("PreferredSprintMode") then
		Character:SetAttribute("PreferredSprintMode", SavedSprintType)
	else
		SavedSprintType = Character:GetAttribute("PreferredSprintMode")
		CurrentSprintType = SavedSprintType
	end

	Packets.MovementStateChanged:Fire("walk")
end)

Packets.MovementStateChanged:Fire("walk")