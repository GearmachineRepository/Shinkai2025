--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local DashBalance = require(Shared.Configurations.Balance.DashBalance)

local DashValidator = {}

export type ValidationContext = {
	Character: Model,
	CurrentStamina: number,
	IsOnCooldown: boolean,
}

export type ValidationResult = {
	Success: boolean,
	Reason: string?,
}

function DashValidator.CanDash(Context: ValidationContext): ValidationResult
	if not Context.Character then
		return {
			Success = false,
			Reason = "NoCharacter",
		}
	end

	if Context.Character:GetAttribute("Stunned") then
		return {
			Success = false,
			Reason = "Stunned",
		}
	end

	if Context.Character:GetAttribute("Ragdolled") then
		return {
			Success = false,
			Reason = "Ragdolled",
		}
	end

	if Context.Character:GetAttribute("Dashing") then
		return {
			Success = false,
			Reason = "AlreadyDashing",
		}
	end

	if Context.IsOnCooldown then
		return {
			Success = false,
			Reason = "OnCooldown",
		}
	end

	if Context.CurrentStamina < DashBalance.StaminaCost then
		return {
			Success = false,
			Reason = "InsufficientStamina",
		}
	end

	return {
		Success = true,
	}
end

return DashValidator
