--!strict

local Types = require(script.Parent.Parent.Types)

type HookDefinition = Types.HookDefinition

type HookLoaderState = {
	HooksFolder: Instance?,
	LoadedHooks: { [string]: HookDefinition },
}

local State: HookLoaderState = {
	HooksFolder = nil,
	LoadedHooks = {},
}

local HookLoader = {}

local function ValidateHookModule(_ModuleName: string, Module: any): (boolean, string?)
	if type(Module) ~= "table" then
		return false, "Hook must return a table"
	end

	if Module.HookName == nil then
		return false, "Hook missing 'HookName' field"
	end

	if type(Module.HookName) ~= "string" then
		return false, "'HookName' must be a string"
	end

	if Module.OnActivate == nil then
		return false, "Hook missing 'OnActivate' function"
	end

	if type(Module.OnActivate) ~= "function" then
		return false, "'OnActivate' must be a function"
	end

	if Module.OnDeactivate ~= nil and type(Module.OnDeactivate) ~= "function" then
		return false, "'OnDeactivate' must be a function if provided"
	end

	if Module.Description ~= nil and type(Module.Description) ~= "string" then
		return false, "'Description' must be a string if provided"
	end

	return true, nil
end

local function LoadSingleHook(ModuleScript: ModuleScript): (HookDefinition?, string?)
	local Success, Result = pcall(require, ModuleScript)
	if not Success then
		return nil, string.format("Failed to require: %s", tostring(Result))
	end

	local IsValid, ValidationError = ValidateHookModule(ModuleScript.Name, Result)
	if not IsValid then
		return nil, ValidationError
	end

	return Result :: HookDefinition, nil
end

function HookLoader.Configure(HooksFolder: Instance)
	State.HooksFolder = HooksFolder
	table.clear(State.LoadedHooks)

	for _, Child in HooksFolder:GetChildren() do
		if not Child:IsA("ModuleScript") then
			continue
		end

		local Hook, ErrorMessage = LoadSingleHook(Child)
		if not Hook then
			error(string.format(Types.EngineName .. " Hook '%s' failed to load: %s", Child.Name, ErrorMessage or "Unknown error"))
		end

		local HookName = Hook.HookName
		if State.LoadedHooks[HookName] then
			error(string.format(Types.EngineName .. " Duplicate hook name: '%s'", HookName))
		end

		State.LoadedHooks[HookName] = Hook
	end
end

function HookLoader.GetHook(HookName: string): HookDefinition?
	return State.LoadedHooks[HookName]
end

function HookLoader.HasHook(HookName: string): boolean
	return State.LoadedHooks[HookName] ~= nil
end

function HookLoader.GetAllHookNames(): { string }
	local Names = {}
	for Name in State.LoadedHooks do
		table.insert(Names, Name)
	end
	return Names
end

function HookLoader.GetHookDescription(HookName: string): string?
	local Hook = State.LoadedHooks[HookName]
	if Hook then
		return Hook.Description
	end
	return nil
end

return HookLoader