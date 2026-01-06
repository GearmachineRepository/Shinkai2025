--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StateTypes = require(Shared.Config.Enums.StateTypes)

export type InputBinding = {
	Input: string,
	RequiredStates: { string }?,
	BlockingStates: { string }?,
	Priority: number,
	Action: string,
}

local InputBindings = {}

InputBindings.Default = {
	{
		Input = "M1",
		RequiredStates = { StateTypes.BLOCKING },
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
		Priority = 100,
		Action = "PerfectGuard",
	},
	{
		Input = "M2",
		RequiredStates = { StateTypes.BLOCKING },
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
		Priority = 100,
		Action = "Counter",
	},
	{
		Input = "M2",
		RequiredStates = { StateTypes.ATTACKING },
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
		Priority = 100,
		Action = "Feint",
	},
	{
		Input = "M1",
		RequiredStates = { StateTypes.DODGING },
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
		Priority = 90,
		Action = "DodgeAttack",
	},
	{
		Input = "M1",
		RequiredStates = { StateTypes.AIRBORNE },
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED },
		Priority = 90,
		Action = "AerialAttack",
	},
	{
		Input = "M1",
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING, StateTypes.BLOCKING },
		Priority = 50,
		Action = "LightAttack",
	},
	{
		Input = "M2",
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },
		Priority = 50,
		Action = "HeavyAttack",
	},
	{
		Input = "Block",
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },
		Priority = 50,
		Action = "Block",
	},
	{
		Input = "Dodge",
		BlockingStates = { StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.RAGDOLLED, StateTypes.EXHAUSTED, StateTypes.ATTACKING },
		Priority = 50,
		Action = "Dodge",
	},
} :: { InputBinding }

function InputBindings.GetSortedBindings(BindingSet: { InputBinding }?): { InputBinding }
	local Bindings = BindingSet or InputBindings.Default
	local Sorted = table.clone(Bindings)
	table.sort(Sorted, function(BindingA, BindingB)
		return BindingA.Priority > BindingB.Priority
	end)
	return Sorted
end

return InputBindings