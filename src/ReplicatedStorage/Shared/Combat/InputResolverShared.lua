--!strict

local InputBindings = require(script.Parent.InputBindings)

type InputBinding = InputBindings.InputBinding
type StateProvider = {
	GetState: (self: StateProvider, StateName: string) -> boolean,
}

local InputResolverShared = {}

local CachedBindings: { InputBinding }? = nil

local function GetBindings(): { InputBinding }
	if not CachedBindings then
		CachedBindings = InputBindings.GetSortedBindings()
	end
	return CachedBindings :: { InputBinding }
end

local function CheckStatesFromProvider(
	Provider: StateProvider,
	RequiredStates: { string }?,
	BlockingStates: { string }?
): boolean
	if RequiredStates then
		for _, StateName in RequiredStates do
			if not Provider:GetState(StateName) then
				return false
			end
		end
	end

	if BlockingStates then
		for _, StateName in BlockingStates do
			if Provider:GetState(StateName) then
				return false
			end
		end
	end

	return true
end

local function CheckStatesFromTable(
	States: { [string]: boolean },
	RequiredStates: { string }?,
	BlockingStates: { string }?
): boolean
	if RequiredStates then
		for _, StateName in RequiredStates do
			if not States[StateName] then
				return false
			end
		end
	end

	if BlockingStates then
		for _, StateName in BlockingStates do
			if States[StateName] then
				return false
			end
		end
	end

	return true
end

local function CheckStatesFromCharacter(
	Character: Model,
	RequiredStates: { string }?,
	BlockingStates: { string }?
): boolean
	if RequiredStates then
		for _, StateName in RequiredStates do
			if not Character:GetAttribute(StateName) then
				return false
			end
		end
	end

	if BlockingStates then
		for _, StateName in BlockingStates do
			if Character:GetAttribute(StateName) then
				return false
			end
		end
	end

	return true
end

function InputResolverShared.ResolveFromProvider(RawInput: string, Provider: StateProvider): string?
	local Bindings = GetBindings()

	for _, Binding in Bindings do
		if Binding.Input ~= RawInput then
			continue
		end

		if CheckStatesFromProvider(Provider, Binding.RequiredStates, Binding.BlockingStates) then
			return Binding.Action
		end
	end

	return nil
end

function InputResolverShared.ResolveFromTable(RawInput: string, States: { [string]: boolean }): string?
	local Bindings = GetBindings()

	for _, Binding in Bindings do
		if Binding.Input ~= RawInput then
			continue
		end

		if CheckStatesFromTable(States, Binding.RequiredStates, Binding.BlockingStates) then
			return Binding.Action
		end
	end

	return nil
end

function InputResolverShared.ResolveFromCharacter(RawInput: string, Character: Model): string?
	local Bindings = GetBindings()

	for _, Binding in Bindings do
		if Binding.Input ~= RawInput then
			continue
		end

		if CheckStatesFromCharacter(Character, Binding.RequiredStates, Binding.BlockingStates) then
			return Binding.Action
		end
	end

	return nil
end

function InputResolverShared.CanPerformFromTable(RawInput: string, States: { [string]: boolean }): boolean
	return InputResolverShared.ResolveFromTable(RawInput, States) ~= nil
end

return InputResolverShared