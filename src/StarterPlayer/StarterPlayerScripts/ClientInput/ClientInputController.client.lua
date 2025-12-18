--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart") :: Part

local DIRECTION_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.D] = true,
}

local CurrentlyPressedKeys: { [Enum.KeyCode]: boolean } = {}
local ActiveDashMover: LinearVelocity? = nil
local ActiveDashAttachment: Attachment? = nil

local DASH_CONFIG = {
	Power = 50,
	Duration = 0.45,
	TweenDuration = 1.1,
	MaxForce = 100000,
	Cooldown = 1,
}

local LastDashTime = 0

local function GetDashDirection(): Vector3?
	local Camera = workspace.CurrentCamera
	if not Camera then
		return nil
	end

	local CameraLookVector = Camera.CFrame.LookVector
	local CameraRightVector = Camera.CFrame.RightVector

	local Forward = if CurrentlyPressedKeys[Enum.KeyCode.W] then CameraLookVector else Vector3.zero
	local Backward = if CurrentlyPressedKeys[Enum.KeyCode.S] then -CameraLookVector else Vector3.zero
	local Left = if CurrentlyPressedKeys[Enum.KeyCode.A] then -CameraRightVector else Vector3.zero
	local Right = if CurrentlyPressedKeys[Enum.KeyCode.D] then CameraRightVector else Vector3.zero

	local Direction = Forward + Backward + Left + Right

	if Direction.Magnitude > 0 then
		return Vector3.new(Direction.X, 0, Direction.Z).Unit
	end

	return nil
end

local function CanDash(): boolean
	if tick() - LastDashTime < DASH_CONFIG.Cooldown then
		return false
	end

	if Character:GetAttribute("Stunned") or Character:GetAttribute("Ragdolled") then
		return false
	end

	if ActiveDashMover then
		return false
	end

	return true
end

local function CleanupDash()
	if ActiveDashMover and ActiveDashMover.Parent then
		ActiveDashMover:Destroy()
	end
	if ActiveDashAttachment and ActiveDashAttachment.Parent then
		ActiveDashAttachment:Destroy()
	end
	ActiveDashMover = nil
	ActiveDashAttachment = nil
end

local function ExecuteDash(Direction: Vector3)
	CleanupDash()

	local Attachment = Instance.new("Attachment")
	Attachment.Parent = HumanoidRootPart

	local LinearVel = Instance.new("LinearVelocity")
	LinearVel.Attachment0 = Attachment
	LinearVel.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	LinearVel.VectorVelocity = Vector3.new(0, 0, -DASH_CONFIG.Power)
	LinearVel.MaxForce = DASH_CONFIG.MaxForce
	LinearVel.Parent = HumanoidRootPart

	Attachment.WorldCFrame = CFrame.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + Direction)

	ActiveDashMover = LinearVel
	ActiveDashAttachment = Attachment

	local TweenInfo = TweenInfo.new(DASH_CONFIG.TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local Tween = TweenService:Create(LinearVel, TweenInfo, {
		VectorVelocity = Vector3.new(0, 0, 0),
	})

	Tween:Play()

	task.delay(DASH_CONFIG.Duration, function()
		CleanupDash()
	end)
end

local function UpdateDashDirection()
	if not ActiveDashMover or not ActiveDashAttachment then
		return
	end

	local Direction = GetDashDirection()
	if Direction and ActiveDashAttachment.Parent then
		ActiveDashAttachment.WorldCFrame =
			CFrame.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + Direction)
	end
end

local function RequestDash()
	if not CanDash() then
		return
	end

	local Direction = GetDashDirection()
	if not Direction then
		return
	end

	Packets.PerformAction:Fire("Dash", { Direction = Direction })
end

Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
	if ActionName == "Dash" then
		local Direction = GetDashDirection()
		if Direction then
			LastDashTime = tick()
			ExecuteDash(Direction)
		end
	end
end)

InputBuffer.OnAction(function(ActionName: string)
	if ActionName == "M1" then
		Packets.PerformAction:Fire("M1")
	elseif ActionName == "M2" then
		Packets.PerformAction:Fire("M2")
	elseif ActionName == "Block" then
		Packets.PerformAction:Fire("Block")
	elseif ActionName == "Skill1" then
		Packets.PerformAction:Fire("Skill1")
	elseif ActionName == "Skill2" then
		Packets.PerformAction:Fire("Skill2")
	elseif ActionName == "Skill3" then
		Packets.PerformAction:Fire("Skill3")
	elseif ActionName == "Skill4" then
		Packets.PerformAction:Fire("Skill4")
	elseif ActionName == "Skill5" then
		Packets.PerformAction:Fire("Skill5")
	elseif ActionName == "Skill6" then
		Packets.PerformAction:Fire("Skill6")
	elseif ActionName == "Dash" then
		RequestDash()
	end
end)

UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	if DIRECTION_KEYS[Input.KeyCode] then
		CurrentlyPressedKeys[Input.KeyCode] = true
	end
end)

UserInputService.InputEnded:Connect(function(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	if DIRECTION_KEYS[Input.KeyCode] then
		CurrentlyPressedKeys[Input.KeyCode] = nil
	end
end)

RunService.Heartbeat:Connect(UpdateDashDirection)
