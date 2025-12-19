--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BaseAction = require(Shared.Actions.ActionDefinitions.BaseAction)
local AnimationService = require(Shared.General.AnimationService)
local SoundPlayer = require(Shared.General.SoundPlayer)

local PARRY_ANIMATION_ID = "YOUR_PARRY_ANIMATION_ID_HERE"
local PARRY_WINDOW_DURATION = 0.3
local PARRY_COOLDOWN = 2.0
local PARRY_STAMINA_COST = 15

local ParryAction = setmetatable({}, BaseAction)
ParryAction.__index = ParryAction

function ParryAction.new()
	local self = BaseAction.new({
		Name = "Parry",
		CooldownDuration = PARRY_COOLDOWN,
		StaminaCost = PARRY_STAMINA_COST,
	})

	return setmetatable(self, ParryAction)
end

function ParryAction:Validate(Context: BaseAction.ActionContext): BaseAction.ValidationResult
	local BaseValidation = BaseAction.Validate(self, Context)
	if not BaseValidation.Success then
		return BaseValidation
	end

	if Context.Character:GetAttribute("Parrying") then
		return {
			Success = false,
			Reason = "AlreadyParrying",
		}
	end

	if Context.Character:GetAttribute("Attacking") then
		return {
			Success = false,
			Reason = "CannotParryWhileAttacking",
		}
	end

	return {
		Success = true,
	}
end

function ParryAction:ExecuteClient(Context: BaseAction.ActionContext): BaseAction.ActionResult
	local Character = Context.Character

	SoundPlayer.Play(Character, "Parry")

	local ParryAnimation = nil
	if Context.Player then
		ParryAnimation = AnimationService.Play(Context.Player, PARRY_ANIMATION_ID, {
			Priority = Enum.AnimationPriority.Action,
			FadeTime = 0.05,
			Speed = 1.0,
		})
	end

	Character:SetAttribute("Parrying", true)

	task.delay(PARRY_WINDOW_DURATION, function()
		Character:SetAttribute("Parrying", false)
		if ParryAnimation then
			ParryAnimation:Stop(0.1)
		end
	end)

	return {
		Success = true,
		RollbackData = {
			Animation = ParryAnimation,
		},
	}
end

function ParryAction:ExecuteServer(Context: BaseAction.ActionContext): BaseAction.ActionResult
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

	Context.Character:SetAttribute("Parrying", true)

	if Entity.States then
		Entity.States:SetState("Parrying", true)
	end

	task.delay(PARRY_WINDOW_DURATION, function()
		Context.Character:SetAttribute("Parrying", false)

		if Entity.States then
			Entity.States:SetState("Parrying", false)
		end
	end)

	return {
		Success = true,
		RollbackData = {
			StaminaConsumed = self.StaminaCost,
		},
	}
end

function ParryAction:RollbackClient(Context: BaseAction.ActionContext, RollbackData: any?)
	Context.Character:SetAttribute("Parrying", false)

	if not RollbackData then
		return
	end

	if RollbackData.Animation then
		RollbackData.Animation:Stop(0.05)
	end
end

return ParryAction
