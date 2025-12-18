--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local DashBalance = require(Shared.Configurations.Balance.DashBalance)
local DashValidator = require(Shared.ActionValidation.DashValidator)
local AnimationService = require(Shared.General.AnimationService)
local SoundPlayer = require(Shared.General.SoundPlayer)
local VfxPlayer = require(Shared.VFX.VfxPlayer)

local Player = Players.LocalPlayer

local DashController = {}

local ActiveDashMover: LinearVelocity? = nil
local ActiveDashAttachment: Attachment? = nil
local IsOnCooldown = false
local ActiveDashAnimation: AnimationTrack? = nil
local _ActiveDashVfx: any? = nil

local DIRECTION_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.D] = true,
}

local DODGE_ANIMATIONS = {
	ForwardDodge = "70739772310093",
	BackDodge = "123040873946149",
	LeftDodge = "109465464856620",
	RightDodge = "140455983078908",
}

AnimationService.Preload(Players.LocalPlayer, DODGE_ANIMATIONS)

local CurrentlyPressedKeys: { [Enum.KeyCode]: boolean } = {}

function DashController.GetCharacter(): Model?
	return Player.Character
end

function DashController.GetHumanoidRootPart(): Part?
	local Character = DashController.GetCharacter()
	if not Character then
		return nil
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
		return HumanoidRootPart :: Part
	end

	return nil
end

function DashController.Initialize()
	Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
		if ActionName == "Dash" then
			DashController.OnServerApproval()
		end
	end)

	Packets.ActionDenied.OnClientEvent:Connect(function(ActionName: string)
		if ActionName == "Dash" then
			DashController.OnServerDenied()
		end
	end)

	Packets.StartCooldown.OnClientEvent:Connect(function(CooldownId: string, _StartTime: number, Duration: number)
		if CooldownId == "Dash" then
			DashController.StartCooldown(Duration)
		end
	end)

	RunService.Heartbeat:Connect(DashController.UpdateDashDirection)
end

function DashController.GetDashDirection(): Vector3?
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

function DashController.GetDashDirectionKey(): string?
	if CurrentlyPressedKeys[Enum.KeyCode.W] then
		return "ForwardDodge"
	end
	if CurrentlyPressedKeys[Enum.KeyCode.S] then
		return "BackDodge"
	end
	if CurrentlyPressedKeys[Enum.KeyCode.A] then
		return "LeftDodge"
	end
	if CurrentlyPressedKeys[Enum.KeyCode.D] then
		return "RightDodge"
	end

	return nil
end

function DashController.CanDash(): (boolean, string?)
	local Character = DashController.GetCharacter()
	if not Character then
		return false, "No character"
	end

	local CurrentStamina = Character:GetAttribute("Stamina") or 0

	local ValidationResult = DashValidator.CanDash({
		Character = Character,
		CurrentStamina = CurrentStamina,
		IsOnCooldown = IsOnCooldown,
	})

	return ValidationResult.Success, ValidationResult.Reason
end

function DashController.RequestDash()
	local CanDash, _Reason = DashController.CanDash()
	if not CanDash then
		return
	end

	local Direction = DashController.GetDashDirection()
	if not Direction then
		return
	end

	DashController.ExecuteDash(Direction)

	Packets.PerformAction:Fire("Dash", { Direction = Direction })
end

function DashController.ExecuteDash(Direction: Vector3)
	DashController.CleanupDash(true)

	local HumanoidRootPart = DashController.GetHumanoidRootPart()
	if not HumanoidRootPart then
		return
	end

	local Character = DashController.GetCharacter()
	if Character then
		SoundPlayer.Play(Character, "Dodge")
		Packets.PlaySound:Fire("Dodge")

		_ActiveDashVfx = VfxPlayer.PlayLocal("DodgeVfx")
	end

	local Attachment = Instance.new("Attachment")
	Attachment.Parent = HumanoidRootPart

	local LinearVel = Instance.new("LinearVelocity")
	LinearVel.Attachment0 = Attachment
	LinearVel.RelativeTo = Enum.ActuatorRelativeTo.World
	LinearVel.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	LinearVel.LineDirection = Direction.Unit
	LinearVel.LineVelocity = DashBalance.Client.Power
	LinearVel.MaxForce = math.huge
	LinearVel.Parent = HumanoidRootPart

	ActiveDashMover = LinearVel
	ActiveDashAttachment = Attachment

	local TweenInfo = TweenInfo.new(DashBalance.Client.TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(LinearVel, TweenInfo, {
		LineVelocity = 0,
	}):Play()

	local DirectionKey = DashController.GetDashDirectionKey()
	if DirectionKey then
		ActiveDashAnimation = AnimationService.Play(Player, DODGE_ANIMATIONS[DirectionKey], {
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.05,
			Speed = 1.0,
		})
	end

	task.delay(DashBalance.Client.AnimationDuration, function()
		DashController.CleanupDash(false)
	end)
end

function DashController.OnServerApproval()
	local Direction = DashController.GetDashDirection()
	if not Direction then
		return
	end

	if not ActiveDashMover then
		DashController.ExecuteDash(Direction)
	end
end

function DashController.OnServerDenied()
	DashController.CleanupDash(true)
end

function DashController.CleanupDash(Rollbacked: boolean)
	if ActiveDashAnimation and Rollbacked then
		ActiveDashAnimation:Stop(0.05)
		ActiveDashAnimation = nil
	end

	local Character = DashController.GetCharacter()

	if Character then
		if Rollbacked then
			VfxPlayer.Cleanup(Character, "DodgeVfx")
		else
			VfxPlayer.Stop(Character, "DodgeVfx")
		end
	end

	_ActiveDashVfx = nil

	if ActiveDashMover and ActiveDashMover.Parent then
		ActiveDashMover:Destroy()
	end
	if ActiveDashAttachment and ActiveDashAttachment.Parent then
		ActiveDashAttachment:Destroy()
	end

	ActiveDashMover = nil
	ActiveDashAttachment = nil
end

function DashController.UpdateDashDirection()
	if not ActiveDashMover or not ActiveDashMover.Parent then
		return
	end

	local Direction = DashController.GetDashDirection()
	if Direction then
		ActiveDashMover.LineDirection = Direction.Unit
	end
end

function DashController.StartCooldown(Duration: number)
	IsOnCooldown = true
	task.wait(Duration)
	IsOnCooldown = false
end

function DashController.SetKeyPressed(KeyCode: Enum.KeyCode, IsPressed: boolean)
	if DIRECTION_KEYS[KeyCode] then
		CurrentlyPressedKeys[KeyCode] = if IsPressed then true else nil
	end
end

return DashController
