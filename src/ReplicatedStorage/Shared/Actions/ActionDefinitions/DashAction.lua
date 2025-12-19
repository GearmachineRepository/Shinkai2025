--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseAction = require(Shared.Actions.ActionDefinitions.BaseAction)
local DashBalance = require(Shared.Configurations.Balance.DashBalance)
local AnimationService = require(Shared.General.AnimationService)
local SoundPlayer = require(Shared.General.SoundPlayer)
local VfxPlayer = require(Shared.VFX.VfxPlayer)

local DODGE_ANIMATIONS = {
	ForwardDodge = "70739772310093",
	BackDodge = "123040873946149",
	LeftDodge = "109465464856620",
	RightDodge = "140455983078908",
}

local DIRECTION_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.D] = true,
}

local DashAction = setmetatable({}, BaseAction)
DashAction.__index = DashAction

function DashAction.new()
	local self = BaseAction.new({
		Name = "Dash",
		CooldownDuration = DashBalance.CooldownSeconds,
		StaminaCost = DashBalance.StaminaCost,
	})

	return setmetatable(self, DashAction)
end

function DashAction:Validate(Context: BaseAction.ActionContext): BaseAction.ValidationResult
	local BaseValidation = BaseAction.Validate(self, Context)
	if not BaseValidation.Success then
		return BaseValidation
	end

	if Context.Character:GetAttribute("Dashing") then
		return {
			Success = false,
			Reason = "AlreadyDashing",
		}
	end

	if not Context.ActionData or not Context.ActionData.Direction then
		return {
			Success = false,
			Reason = "NoDirection",
		}
	end

	local Direction = Context.ActionData.Direction
	if typeof(Direction) ~= "Vector3" then
		return {
			Success = false,
			Reason = "InvalidDirection",
		}
	end

	local Magnitude = Direction.Magnitude
	if Magnitude < 0.9 or Magnitude > 1.1 then
		return {
			Success = false,
			Reason = "InvalidDirectionMagnitude",
		}
	end

	if math.abs(Direction.Y) > 0.1 then
		return {
			Success = false,
			Reason = "InvalidDirectionY",
		}
	end

	return {
		Success = true,
	}
end

function DashAction:GetCurrentPressedKeys(): { [Enum.KeyCode]: boolean }
	local PressedKeys = {}

	for KeyCode in DIRECTION_KEYS do
		if UserInputService:IsKeyDown(KeyCode) then
			PressedKeys[KeyCode] = true
		end
	end

	return PressedKeys
end

function DashAction:GetDashDirectionFromKeys(): Vector3?
	local Camera = workspace.CurrentCamera
	if not Camera then
		return nil
	end

	local PressedKeys = self:GetCurrentPressedKeys()

	local CameraLookVector = Camera.CFrame.LookVector
	local CameraRightVector = Camera.CFrame.RightVector

	local Forward = if PressedKeys[Enum.KeyCode.W] then CameraLookVector else Vector3.zero
	local Backward = if PressedKeys[Enum.KeyCode.S] then -CameraLookVector else Vector3.zero
	local Left = if PressedKeys[Enum.KeyCode.A] then -CameraRightVector else Vector3.zero
	local Right = if PressedKeys[Enum.KeyCode.D] then CameraRightVector else Vector3.zero

	local Direction = Forward + Backward + Left + Right

	if Direction.Magnitude > 0 then
		return Vector3.new(Direction.X, 0, Direction.Z).Unit
	end

	return nil
end

function DashAction:ExecuteClient(Context: BaseAction.ActionContext): BaseAction.ActionResult
	local Result = BaseAction.ExecuteClient(self, Context)

	local Character = Context.Character
	local Direction = Context.ActionData.Direction

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart or not HumanoidRootPart:IsA("BasePart") then
		return {
			Success = false,
			Reason = "NoHumanoidRootPart",
		}
	end

	local Sound = SoundPlayer.Play(Character, "Dodge")
	if Sound then
		self:AddCleanupTask(Sound)
	end

	local DashVfx = VfxPlayer.PlayLocal("DodgeVfx")
	if DashVfx then
		self:AddInstantCleanupTask(function()
			VfxPlayer.Cleanup(Character, "DodgeVfx", true)
		end)
	end

	local Attachment = Instance.new("Attachment")
	Attachment.Parent = HumanoidRootPart
	Attachment.WorldCFrame = CFrame.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + Direction)
	self:AddCleanupTask(Attachment)

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	LinearVelocity.VectorVelocity = Vector3.new(0, 0, -DashBalance.Client.Power)
	LinearVelocity.MaxForce = DashBalance.Client.MaxForce
	LinearVelocity.Parent = HumanoidRootPart
	self:AddCleanupTask(LinearVelocity)

	local TweenInfo = TweenInfo.new(DashBalance.Client.TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local VelocityTween = TweenService:Create(LinearVelocity, TweenInfo, {
		VectorVelocity = Vector3.new(0, 0, 0),
	})
	VelocityTween:Play()
	self:AddCleanupTask(VelocityTween)

	local ConnectionCleanup = {}

	local UpdateConnection = RunService.Heartbeat:Connect(function()
		if self.IsRolledBack then
			return
		end

		if not Attachment.Parent then
			return
		end

		local CurrentDirection = self:GetDashDirectionFromKeys()
		if CurrentDirection then
			Attachment.WorldCFrame =
				CFrame.lookAt(HumanoidRootPart.Position, HumanoidRootPart.Position + CurrentDirection)
		end
	end)

	table.insert(ConnectionCleanup, UpdateConnection)
	self:AddCleanupTask(function()
		for _, Connection in ConnectionCleanup do
			Connection:Disconnect()
		end
	end)

	local DirectionKey = self:GetDirectionKey(Context)
	local DashAnimation = nil

	if DirectionKey and Context.Player then
		DashAnimation = AnimationService.Play(Context.Player, DODGE_ANIMATIONS[DirectionKey], {
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.05,
			Speed = 1.0,
		})

		if DashAnimation then
			self:AddCleanupTask(function()
				DashAnimation:Stop(0.25)
			end)
		end
	end

	task.delay(DashBalance.Client.AnimationDuration, function()
		if self.IsRolledBack then
			return
		end

		if Result.RollbackData and Result.RollbackData.Maid then
			Result.RollbackData.Maid:DoCleaning()
		end

		VfxPlayer.Stop(Character, "DodgeVfx")
	end)

	Result.Success = true
	return Result
end

function DashAction:ExecuteServer(Context: BaseAction.ActionContext): BaseAction.ActionResult
	local Entity = Context.Entity
	if not Entity or not Entity.Components then
		return {
			Success = false,
			Reason = "NoEntity",
		}
	end

	if not Entity.Components.Stamina then
		return {
			Success = false,
			Reason = "NoStaminaComponent",
		}
	end

	if not Entity.Components.Stamina:ConsumeStamina(self.StaminaCost) then
		return {
			Success = false,
			Reason = "FailedToConsumeStamina",
		}
	end

	Context.Character:SetAttribute("ActionLocked", true)
	Context.Character:SetAttribute("Dashing", true)

	if Entity.States then
		Entity.States:SetState("Dashing", true)
	end

	task.delay(DashBalance.DashDurationSeconds, function()
		if Entity.States then
			Entity.States:SetState("Dashing", false)
		end

		if Context.Character then
			Context.Character:SetAttribute("ActionLocked", false)
			Context.Character:SetAttribute("Dashing", false)
			Context.Character:SetAttribute("MovementMode", "walk")
		end
	end)

	return {
		Success = true,
		RollbackData = {
			StaminaConsumed = self.StaminaCost,
		},
	}
end

function DashAction:RollbackClient(Context: BaseAction.ActionContext, RollbackData: any?)
	BaseAction.RollbackClient(self, Context, RollbackData)
end

function DashAction:GetDirectionKey(Context: BaseAction.ActionContext): string?
	local Direction = Context.ActionData.Direction
	if not Direction then
		return nil
	end

	local Camera = workspace.CurrentCamera
	if not Camera then
		return nil
	end

	local CameraLookVector = Camera.CFrame.LookVector
	local CameraRightVector = Camera.CFrame.RightVector

	local ForwardDot = Direction:Dot(CameraLookVector)
	local RightDot = Direction:Dot(CameraRightVector)

	if math.abs(ForwardDot) > math.abs(RightDot) then
		if ForwardDot > 0 then
			return "ForwardDodge"
		else
			return "BackDodge"
		end
	else
		if RightDot > 0 then
			return "RightDodge"
		else
			return "LeftDodge"
		end
	end
end

return DashAction
