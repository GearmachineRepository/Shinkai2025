--!strict

local Types = require(script.Parent.Parent.Types)

type ComponentModule = Types.ComponentModule
type ComponentMetadata = Types.ComponentMetadata

type LoadedComponent = {
	Module: ComponentModule,
	Metadata: ComponentMetadata,
}

type ComponentLoaderState = {
	ComponentsFolder: Instance?,
	LoadedComponents: { [string]: LoadedComponent },
	DependencyGraph: { [string]: { string } },
}

local State: ComponentLoaderState = {
	ComponentsFolder = nil,
	LoadedComponents = {},
	DependencyGraph = {},
}

local ComponentLoader = {}

local function ValidateComponentModule(_ModuleName: string, Module: any): (boolean, string?)
	if type(Module) ~= "table" then
		return false, "Module must return a table"
	end

	if Module.ComponentName == nil then
		return false, "Module missing 'ComponentName' field"
	end

	if type(Module.ComponentName) ~= "string" then
		return false, "'ComponentName' must be a string"
	end

	if type(Module.new) ~= "function" then
		return false, "Module missing 'new' constructor function"
	end

	if Module.Dependencies ~= nil and type(Module.Dependencies) ~= "table" then
		return false, "'Dependencies' must be an array of strings"
	end

	if Module.UpdateRate ~= nil and type(Module.UpdateRate) ~= "number" then
		return false, "'UpdateRate' must be a number"
	end

	return true, nil
end

local function LoadSingleComponent(ModuleScript: ModuleScript): (LoadedComponent?, string?)
	local Success, Result = pcall(require, ModuleScript)
	if not Success then
		return nil, string.format("Failed to require: %s", tostring(Result))
	end

	local IsValid, ValidationError = ValidateComponentModule(ModuleScript.Name, Result)
	if not IsValid then
		return nil, ValidationError
	end

	local Metadata: ComponentMetadata = {
		ComponentName = Result.ComponentName,
		Dependencies = Result.Dependencies,
		UpdateRate = Result.UpdateRate,
	}

	return {
		Module = Result,
		Metadata = Metadata,
	}, nil
end

function ComponentLoader.Configure(ComponentsFolder: Instance)
	State.ComponentsFolder = ComponentsFolder
	table.clear(State.LoadedComponents)
	table.clear(State.DependencyGraph)

	for _, Child in ComponentsFolder:GetChildren() do
		if not Child:IsA("ModuleScript") then
			continue
		end

		local LoadedComponent, ErrorMessage = LoadSingleComponent(Child)
		if not LoadedComponent then
			error(string.format(Types.EngineName .. " Component '%s' failed to load: %s", Child.Name, ErrorMessage or "Unknown error"))
		end

		local ComponentName = LoadedComponent.Metadata.ComponentName
		if State.LoadedComponents[ComponentName] then
			error(string.format(Types.EngineName .. " Duplicate component name: '%s'", ComponentName))
		end

		State.LoadedComponents[ComponentName] = LoadedComponent
		State.DependencyGraph[ComponentName] = LoadedComponent.Metadata.Dependencies or {}
	end

	ComponentLoader.ValidateDependencies()
end

function ComponentLoader.ValidateDependencies()
	local CoreComponents = { "States", "Stats", "Modifiers", "Hooks" }
	local AvailableComponents: { [string]: boolean } = {}

	for _, CoreName in CoreComponents do
		AvailableComponents[CoreName] = true
	end

	for ComponentName in State.LoadedComponents do
		AvailableComponents[ComponentName] = true
	end

	for ComponentName, Dependencies in State.DependencyGraph do
		for _, Dependency in Dependencies do
			if not AvailableComponents[Dependency] then
				error(string.format(
					"[Arch] Component '%s' depends on '%s', which does not exist",
					ComponentName,
					Dependency
				))
			end
		end
	end

	for ComponentName in State.LoadedComponents do
		local Visited: { [string]: boolean } = {}
		local Stack: { [string]: boolean } = {}

		local function HasCycle(Name: string): boolean
			if Stack[Name] then
				return true
			end
			if Visited[Name] then
				return false
			end

			Visited[Name] = true
			Stack[Name] = true

			local Dependencies = State.DependencyGraph[Name] or {}
			for _, Dependency in pairs(Dependencies) do
				if HasCycle(Dependency) then
					return true
				end
			end

			Stack[Name] = false
			return false
		end

		if HasCycle(ComponentName) then
			error(string.format(Types.EngineName .. " Circular dependency detected involving '%s'", ComponentName))
		end
	end
end

function ComponentLoader.GetComponent(ComponentName: string): LoadedComponent?
	return State.LoadedComponents[ComponentName]
end

function ComponentLoader.HasComponent(ComponentName: string): boolean
	return State.LoadedComponents[ComponentName] ~= nil
end

function ComponentLoader.GetDependencies(ComponentName: string): { string }
	return State.DependencyGraph[ComponentName] or {}
end

function ComponentLoader.GetAllComponentNames(): { string }
	local Names = {}
	for Name in State.LoadedComponents do
		table.insert(Names, Name)
	end
	return Names
end

function ComponentLoader.GetComponentsWithUpdates(): { { Name: string, Rate: number } }
	local Components = {}
	for Name, Loaded in State.LoadedComponents do
		if Loaded.Metadata.UpdateRate then
			table.insert(Components, {
				Name = Name,
				Rate = Loaded.Metadata.UpdateRate,
			})
		end
	end
	return Components
end

function ComponentLoader.ResolveDependencyOrder(ComponentNames: { string }): { string }
	local Resolved: { string } = {}
	local ResolvedSet: { [string]: boolean } = {}
	local Visiting: { [string]: boolean } = {}

	local function Visit(Name: string)
		if ResolvedSet[Name] then
			return
		end

		if Visiting[Name] then
			return
		end

		Visiting[Name] = true

		local Dependencies = State.DependencyGraph[Name] or {}
		for _, Dependency in pairs(Dependencies) do
			if State.LoadedComponents[Dependency] then
				Visit(Dependency)
			end
		end

		Visiting[Name] = false
		ResolvedSet[Name] = true
		table.insert(Resolved, Name)
	end

	for _, Name in ComponentNames do
		if State.LoadedComponents[Name] then
			Visit(Name)
		end
	end

	return Resolved
end

return ComponentLoader