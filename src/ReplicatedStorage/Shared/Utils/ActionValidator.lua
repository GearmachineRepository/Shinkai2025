--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local ActionValidator = {}

ActionValidator.Blocking = {
	LightAttack = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING, StateTypes.BLOCKING },
	HeavyAttack = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },
	Feint = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
	Block = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },
	Dodge = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },
	PerfectGuard = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
	Counter = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },

	M1 = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING, StateTypes.BLOCKING },
	M2 = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },

	Jog = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.EXHAUSTED, StateTypes.DOWNED },
	Run = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.EXHAUSTED, StateTypes.DOWNED },
}

ActionValidator.Required = {
	PerfectGuard = { StateTypes.BLOCKING },
	Counter = { StateTypes.BLOCKING },
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

function ActionValidator.AddBlockingState(ActionName: string, StateName: string)
	if not ActionValidator.Blocking[ActionName] then
		ActionValidator.Blocking[ActionName] = {}
	end

	if not table.find(ActionValidator.Blocking[ActionName], StateName) then
		table.insert(ActionValidator.Blocking[ActionName], StateName)
	end
end

function ActionValidator.RemoveBlockingState(ActionName: string, StateName: string)
	local BlockingStates = ActionValidator.Blocking[ActionName]
	if not BlockingStates then
		return
	end

	local Index = table.find(BlockingStates, StateName)
	if Index then
		table.remove(BlockingStates, Index)
	end
end

function ActionValidator.AddRequiredState(ActionName: string, StateName: string)
	if not ActionValidator.Required[ActionName] then
		ActionValidator.Required[ActionName] = {}
	end

	if not table.find(ActionValidator.Required[ActionName], StateName) then
		table.insert(ActionValidator.Required[ActionName], StateName)
	end
end

function ActionValidator.RemoveRequiredState(ActionName: string, StateName: string)
	local RequiredStates = ActionValidator.Required[ActionName]
	if not RequiredStates then
		return
	end

	local Index = table.find(RequiredStates, StateName)
	if Index then
		table.remove(RequiredStates, Index)
	end
end

return ActionValidator