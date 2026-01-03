
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatValidationConfig = require(Shared.Configurations.CombatValidationConfig)

local ActionValidator = {}

export type ValidationOverrides = {
        IgnoreBlockedStates: { [string]: boolean }?,
}

function ActionValidator.CanPerform(States: any, ActionName: string, Overrides: ValidationOverrides?): (boolean, string?)
        if not States then
                return false, "MissingStateComponent"
        end

	local ActionDef = CombatValidationConfig.Actions[ActionName]
	if not ActionDef then
		return true, nil
	end

        local IgnoreBlockedStates = Overrides and Overrides.IgnoreBlockedStates

        if ActionDef.BlockedBy then
                for _, StateName in ActionDef.BlockedBy do
                        if not (IgnoreBlockedStates and IgnoreBlockedStates[StateName]) and States:GetState(StateName) then
                                return false, StateName
                        end
                end
        end

	if ActionDef.RequiredStates then
		for _, StateName in ActionDef.RequiredStates do
			if not States:GetState(StateName) then
				return false, "Missing" .. StateName
			end
		end
	end

        return true, nil
end

function ActionValidator.CanPerformClient(Character: Model, ActionName: string, Overrides: ValidationOverrides?): (boolean, string?)
        if not Character then
                return false, "MissingCharacter"
        end

	local ActionDef = CombatValidationConfig.Actions[ActionName]
	if not ActionDef then
		return true, nil
	end

        local IgnoreBlockedStates = Overrides and Overrides.IgnoreBlockedStates

        if ActionDef.BlockedBy then
                for _, StateName in ActionDef.BlockedBy do
                        if not (IgnoreBlockedStates and IgnoreBlockedStates[StateName]) and Character:GetAttribute(StateName) then
                                return false, StateName
                        end
                end
	end

	if ActionDef.RequiredStates then
		for _, StateName in ActionDef.RequiredStates do
			if not Character:GetAttribute(StateName) then
				return false, "Missing" .. StateName
			end
		end
	end

	return true, nil
end

function ActionValidator.IsBlockedBy(ActionName: string): { string }?
	local ActionDef = CombatValidationConfig.Actions[ActionName]
	if ActionDef then
		return ActionDef.BlockedBy
	end
	return nil
end

function ActionValidator.GetRequiredStates(ActionName: string): { string }?
	local ActionDef = CombatValidationConfig.Actions[ActionName]
	if ActionDef then
		return ActionDef.RequiredStates
	end
	return nil
end

return ActionValidator