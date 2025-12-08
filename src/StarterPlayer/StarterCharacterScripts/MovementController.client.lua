local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Configurations")

local StatEnums = require(Config.Enums.StatTypes)

local Player = Players.LocalPlayer
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

local DOUBLE_TAP_TIME = 0.3

local LastWPressTime = 0
local IsInSprintMode = false
local CurrentSprintType = "run"
local SavedSprintType = "run"
local IsShiftHeld = false
local IsWHeld = false

if not Character:GetAttribute("MovementMode") then
	Character:SetAttribute("MovementMode", "walk")
end

if not Character:GetAttribute("PreferredSprintMode") then
	Character:SetAttribute("PreferredSprintMode", "run")
else
	SavedSprintType = Character:GetAttribute("PreferredSprintMode")
	CurrentSprintType = SavedSprintType
end

local function CanSprint(): boolean
	return not Character:GetAttribute("Exhausted")
end

local function CanJog(): boolean
	return not Character:GetAttribute("Exhausted")
end

local function SetMovementMode(Mode: string)
	if Mode == "walk" then
		IsInSprintMode = false
		Packets.MovementStateChanged:Fire("walk")

	elseif Mode == "jog" then
		if not CanJog() then
			SetMovementMode("walk")
			return
		end
		Character:SetAttribute("PreferredSprintMode", "jog")
		IsInSprintMode = true
		CurrentSprintType = "jog"
		SavedSprintType = "jog"
		Packets.MovementStateChanged:Fire("jog")

	elseif Mode == "run" then
		if not CanSprint() then
			SetMovementMode("walk")
			return
		end
		Character:SetAttribute("PreferredSprintMode", "run")
		IsInSprintMode = true
		CurrentSprintType = "run"
		SavedSprintType = "run"
		Packets.MovementStateChanged:Fire("run")
	end
end

local function EnterSprintMode()
	if not IsWHeld then return end

	if SavedSprintType == "jog" then
		SetMovementMode("jog")
	else
		SetMovementMode("run")
	end
end

local function ExitSprintMode()
	if IsInSprintMode then
		SetMovementMode("walk")
	end
end

local function ToggleSprintType()
	if not IsInSprintMode then return end

	if CurrentSprintType == "run" then
		SetMovementMode("jog")
	else
		SetMovementMode("run")
	end
end

local function OnInputBegan(Input, GameProcessedEvent)
	if GameProcessedEvent then return end

	if Input.KeyCode == Enum.KeyCode.W then
		IsWHeld = true

		local CurrentTime = tick()
		if CurrentTime - LastWPressTime <= DOUBLE_TAP_TIME then
			EnterSprintMode()
		end
		LastWPressTime = CurrentTime

	elseif Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.RightShift then
		IsShiftHeld = true
		EnterSprintMode()

	elseif Input.KeyCode == Enum.KeyCode.R then
		ToggleSprintType()
	end
end

local function OnInputEnded(Input, GameProcessedEvent)
	if GameProcessedEvent then return end

	if Input.KeyCode == Enum.KeyCode.W then
		IsWHeld = false
		if IsInSprintMode then
			ExitSprintMode()
		end

	elseif Input.KeyCode == Enum.KeyCode.LeftShift or Input.KeyCode == Enum.KeyCode.RightShift then
		IsShiftHeld = false
		if IsInSprintMode then
			ExitSprintMode()
		end
	end
end

UserInputService.InputBegan:Connect(OnInputBegan)
UserInputService.InputEnded:Connect(OnInputEnded)

RunService.Heartbeat:Connect(function()
	if Humanoid.MoveDirection.Magnitude < 0.1 and IsInSprintMode then
		if not IsShiftHeld then
			task.wait(0.1)
			if Humanoid.MoveDirection.Magnitude < 0.1 then
				SetMovementMode("walk")
			end
		end
	end
end)

Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
	local ServerMode = Character:GetAttribute("MovementMode")

	if ServerMode == "walk" then
		IsInSprintMode = false

	elseif ServerMode == "jog" then
		IsInSprintMode = true
		CurrentSprintType = "jog"

	elseif ServerMode == "run" then
		IsInSprintMode = true
		CurrentSprintType = "run"
	end
end)

Character:GetAttributeChangedSignal(StatEnums.RUN_SPEED):Connect(function()
	-- No WalkSpeed adjustments anymore
end)

Player.CharacterAdded:Connect(function(NewCharacter)
	Character = NewCharacter
	Humanoid = NewCharacter:WaitForChild("Humanoid")

	if not Character:GetAttribute("MovementMode") then
		Character:SetAttribute("MovementMode", "walk")
	end

	if not Character:GetAttribute("PreferredSprintMode") then
		Character:SetAttribute("PreferredSprintMode", SavedSprintType)
	else
		SavedSprintType = Character:GetAttribute("PreferredSprintMode")
		CurrentSprintType = SavedSprintType
	end

	SetMovementMode("walk")
end)

SetMovementMode("walk")
