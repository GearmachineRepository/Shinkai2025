--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local ActionValidator = {}

ActionValidator.Blocking = {
	M1 = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING, StateTypes.DODGING },
	M2 = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },

	Feint = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
	DodgeCancel = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },

	Block = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING, StateTypes.DODGING },
	Dodge = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING, StateTypes.DODGING },
	Skill = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.DODGING },

	Jog = { StateTypes.ATTACKING, StateTypes.DOWNED, StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.EXHAUSTED, StateTypes.DOWNED, StateTypes.DODGING },
	Run = { StateTypes.ATTACKING, StateTypes.DOWNED, StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.EXHAUSTED, StateTypes.DOWNED, StateTypes.DODGING },
}

ActionValidator.Required = {
	Parry = { StateTypes.BLOCKING },
	DodgeCancel = { StateTypes.DODGING },
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

function ActionValidator.CanPerformClient(Character: Model, ActionName: string): (boolean, string?)
	local BlockingStates = ActionValidator.Blocking[ActionName]
	if BlockingStates then
		for _, StateName in BlockingStates do
			if Character:GetAttribute(StateName) then
				return false, StateName
			end
		end
	end

	local RequiredStates = ActionValidator.Required[ActionName]
	if RequiredStates then
		for _, StateName in RequiredStates do
			if not Character:GetAttribute(StateName) then
				return false, "Missing" .. StateName
			end
		end
	end

	return true, nil
end

return ActionValidator