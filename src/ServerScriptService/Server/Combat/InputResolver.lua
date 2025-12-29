--!strict

local CombatTypes = require(script.Parent.CombatTypes)

type Entity = CombatTypes.Entity

export type InputBinding = {
	Input: string,
	RequiredStates: { string }?,
	BlockingStates: { string }?,
	Priority: number,
	Action: string,
}

export type InputConfig = {
	Bindings: { InputBinding },
}

local InputResolver = {}

local InputConfigs: { [string]: { InputBinding } } = {}

local DEFAULT_BINDINGS: { InputBinding } = {
	{
		Input = "M1",
		RequiredStates = { "Blocking" },
		BlockingStates = { "Stunned", "Downed", "Ragdolled", "Exhausted" },
		Priority = 100,
		Action = "PerfectGuard",
	},
	{
		Input = "M2",
		RequiredStates = { "Blocking" },
		BlockingStates = { "Stunned", "Downed", "Ragdolled", "Exhausted" },
		Priority = 100,
		Action = "Counter",
	},
	-- {
	-- 	Input = "M2",
	-- 	RequiredStates = { "Attacking" },
	-- 	BlockingStates = { "Stunned", "Downed", "Ragdolled" },
	-- 	Priority = 90,
	-- 	Action = "Feint",
	-- },
	{
		Input = "M1",
		BlockingStates = { "Stunned", "Downed", "Ragdolled", "Exhausted", "Attacking", "Blocking" },
		Priority = 50,
		Action = "LightAttack",
	},
	{
		Input = "M2",
		BlockingStates = { "Stunned", "Downed", "Ragdolled", "Exhausted", "Attacking" },
		Priority = 50,
		Action = "HeavyAttack",
	},
	{
		Input = "Block",
		BlockingStates = { "Stunned", "Downed", "Ragdolled", "Exhausted", "Attacking" },
		Priority = 50,
		Action = "Block",
	},
	{
		Input = "Dodge",
		BlockingStates = { "Stunned", "Downed", "Ragdolled", "Exhausted", "Attacking" },
		Priority = 50,
		Action = "Dodge",
	},
}

local function SortBindingsByPriority(Bindings: { InputBinding }): { InputBinding }
	local Sorted = table.clone(Bindings)
	table.sort(Sorted, function(BindingA, BindingB)
		return BindingA.Priority > BindingB.Priority
	end)
	return Sorted
end

local function CheckStates(Entity: Entity, RequiredStates: { string }?, BlockingStates: { string }?): boolean
	local States = Entity.States
	if not States then
		return false
	end

	if RequiredStates then
		for _, StateName in RequiredStates do
			if not States:GetState(StateName) then
				return false
			end
		end
	end

	if BlockingStates then
		for _, StateName in BlockingStates do
			if States:GetState(StateName) then
				return false
			end
		end
	end

	return true
end

function InputResolver.Configure(ConfigName: string, Bindings: { InputBinding })
	InputConfigs[ConfigName] = SortBindingsByPriority(Bindings)
end

function InputResolver.SetDefaultBindings(Bindings: { InputBinding })
	InputConfigs["Default"] = SortBindingsByPriority(Bindings)
end

function InputResolver.Resolve(Entity: Entity, RawInput: string, ConfigName: string?): string?
	local Config = ConfigName and InputConfigs[ConfigName] or InputConfigs["Default"]
	if not Config then
		Config = SortBindingsByPriority(DEFAULT_BINDINGS)
		InputConfigs["Default"] = Config
	end

	for _, Binding in Config do
		if Binding.Input ~= RawInput then
			continue
		end

		local StateCheckPassed = CheckStates(Entity, Binding.RequiredStates, Binding.BlockingStates)

		if StateCheckPassed then
			return Binding.Action
		end
	end

	return nil
end

function InputResolver.GetBindingsForInput(RawInput: string, ConfigName: string?): { InputBinding }
	local Config = ConfigName and InputConfigs[ConfigName] or InputConfigs["Default"]
	if not Config then
		return {}
	end

	local Matches = {}
	for _, Binding in Config do
		if Binding.Input == RawInput then
			table.insert(Matches, Binding)
		end
	end

	return Matches
end

function InputResolver.AddBinding(Binding: InputBinding, ConfigName: string?)
	local TargetConfig = ConfigName or "Default"
	if not InputConfigs[TargetConfig] then
		InputConfigs[TargetConfig] = {}
	end

	table.insert(InputConfigs[TargetConfig], Binding)
	InputConfigs[TargetConfig] = SortBindingsByPriority(InputConfigs[TargetConfig])
end

function InputResolver.RemoveBinding(Action: string, ConfigName: string?)
	local TargetConfig = ConfigName or "Default"
	local Config = InputConfigs[TargetConfig]
	if not Config then
		return
	end

	for Index = #Config, 1, -1 do
		if Config[Index].Action == Action then
			table.remove(Config, Index)
		end
	end
end

function InputResolver.GetAllBindings(ConfigName: string?): { InputBinding }
	local Config = ConfigName and InputConfigs[ConfigName] or InputConfigs["Default"]
	return Config or {}
end

InputResolver.SetDefaultBindings(DEFAULT_BINDINGS)

return InputResolver