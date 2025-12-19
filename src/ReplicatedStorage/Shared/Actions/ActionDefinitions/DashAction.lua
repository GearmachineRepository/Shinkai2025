--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
		self:AddCleanupTask(function()
			VfxPlayer.Cleanup(Character, "DodgeVfx")
		end)
	end

	local Attachment = Instance.new("Attachment")
	Attachment.Parent = HumanoidRootPart
	self:AddCleanupTask(Attachment)

	local LinearVelocity = Instance.new("LinearVelocity")
	LinearVelocity.Attachment0 = Attachment
	LinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	LinearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	LinearVelocity.LineDirection = Direction.Unit
	LinearVelocity.LineVelocity = DashBalance.Client.Power
	LinearVelocity.MaxForce = math.huge
	LinearVelocity.Parent = HumanoidRootPart
	self:AddCleanupTask(LinearVelocity)

	local TweenInfo = TweenInfo.new(DashBalance.Client.TweenDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(LinearVelocity, TweenInfo, {
		LineVelocity = 0,
	}):Play()

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
