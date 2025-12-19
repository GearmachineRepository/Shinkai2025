--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Maid = require(Shared.General.Maid)

export type ActionContext = {
	Entity: any,
	Character: Model,
	Player: Player?,
	ActionData: any?,
}

export type ValidationResult = {
	Success: boolean,
	Reason: string?,
}

export type ActionResult = {
	Success: boolean,
	Reason: string?,
	RollbackData: any?,
}

export type BaseAction = {
	Name: string,
	CooldownDuration: number,
	StaminaCost: number,

	Validate: (self: BaseAction, Context: ActionContext) -> ValidationResult,
	ExecuteClient: (self: BaseAction, Context: ActionContext) -> ActionResult,
	ExecuteServer: (self: BaseAction, Context: ActionContext) -> ActionResult,
	RollbackClient: (self: BaseAction, Context: ActionContext, RollbackData: any?) -> (),
	CanExecute: (self: BaseAction, Context: ActionContext) -> ValidationResult,
	AddCleanupTask: (self: BaseAction, Task: any) -> (),
}

type BaseActionInternal = BaseAction & {
	CleanupMaid: Maid.MaidSelf?,
}

local BaseAction = {}
BaseAction.__index = BaseAction

function BaseAction.new(Config: {
	Name: string,
	CooldownDuration: number?,
	StaminaCost: number?,
}): BaseAction
	local self = setmetatable({
		Name = Config.Name,
		CooldownDuration = Config.CooldownDuration or 0,
		StaminaCost = Config.StaminaCost or 0,
		CleanupMaid = nil,
	}, BaseAction)

	return self :: any
end

function BaseAction:Validate(Context: ActionContext): ValidationResult
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

	return {
		Success = true,
	}
end

function BaseAction:CanExecute(Context: ActionContext): ValidationResult
	local ValidationResult = self:Validate(Context)
	if not ValidationResult.Success then
		return ValidationResult
	end

	if self.StaminaCost > 0 then
		local CurrentStamina = Context.Character:GetAttribute("Stamina") or 0
		if CurrentStamina < self.StaminaCost then
			return {
				Success = false,
				Reason = "InsufficientStamina",
			}
		end
	end

	return {
		Success = true,
	}
end

function BaseAction:AddCleanupTask(Task: any)
	if not self.CleanupMaid then
		warn("[BaseAction] Attempted to add cleanup task without active execution")
		return
	end

	self.CleanupMaid:GiveTask(Task)
end

function BaseAction:ExecuteClient(_Context: ActionContext): ActionResult
	self.CleanupMaid = Maid.new()

	return {
		Success = false,
		Reason = "NotImplemented",
		RollbackData = {
			Maid = self.CleanupMaid,
		},
	}
end

function BaseAction:ExecuteServer(_Context: ActionContext): ActionResult
	return {
		Success = false,
		Reason = "NotImplemented",
	}
end

function BaseAction:RollbackClient(Context: ActionContext, RollbackData: any?)
	if RollbackData and RollbackData.Maid then
		RollbackData.Maid:DoCleaning()
	end

	self.CleanupMaid = nil

	if Context.Character then
		Context.Character:SetAttribute("ActionLocked", false)
	end
end

return BaseAction
