--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local ActionValidator = {}

ActionValidator.Blocking = {
	M1 = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.ATTACKING,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},
	M2 = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.ATTACKING,
		StateTypes.GUARD_BROKEN,
	},

	LightAttack = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.ATTACKING,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},
	HeavyAttack = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.ATTACKING,
		StateTypes.GUARD_BROKEN,
	},

	Feint = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.GUARD_BROKEN,
	},
	DodgeCancel = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
	},

	Block = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.ATTACKING,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},
	Dodge = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.ATTACKING,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},
	Skill = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
		StateTypes.EXHAUSTED,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},

	Jog = {
		StateTypes.ATTACKING,
		StateTypes.BLOCKING,
		StateTypes.STUNNED,
		StateTypes.EXHAUSTED,
		StateTypes.DOWNED,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},
	Run = {
		StateTypes.ATTACKING,
		StateTypes.BLOCKING,
		StateTypes.STUNNED,
		StateTypes.EXHAUSTED,
		StateTypes.DOWNED,
		StateTypes.DODGING,
		StateTypes.GUARD_BROKEN,
	},

	Hitbox = {
		StateTypes.STUNNED,
		StateTypes.DOWNED,
		StateTypes.RAGDOLLED,
	},
}

ActionValidator.Required = {
	Parry = { StateTypes.BLOCKING },
	DodgeCancel = { StateTypes.DODGING },
}

function ActionValidator.CanPerform(States: any, ActionName: string): (boolean, string?)
	if not States then return false, "Missing StateComponent" end

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