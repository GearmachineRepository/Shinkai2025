--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local ActionValidator = {}

ActionValidator.Blocking = {
	M1 = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.BLOCKING, "Exhausted" },
	M2 = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED },
	Block = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.ATTACKING },
	Dodge = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.ATTACKING },
	Skill = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED },

	Jog = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.DOWNED },
	Run = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.DOWNED },
}

ActionValidator.Required = {
	Parry = { StateTypes.BLOCKING },
}

function ActionValidator.CanPerform(States: any, ActionName: string): (boolean, string?)
	local BlockingStates = ActionValidator.Blocking[ActionName]
	if BlockingStates then
		for _, StateName in BlockingStates do
			if States:GetState(StateName) then
				return false, StateName
			end
		end
	end

	local RequiredStates = ActionValidator.Required[ActionName]
	if RequiredStates then
		for _, StateName in RequiredStates do
			if not States:GetState(StateName) then
				return false, "Missing" .. StateName
			end
		end
	end

	return true, nil
end

return ActionValidator