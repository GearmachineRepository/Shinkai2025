--!strict

local Entity = require(script.Parent.Entity)
local ComponentLoader = require(script.Parent.ComponentLoader)
local Types = require(script.Parent.Parent.Types)

type EntityContext = Types.EntityContext
type EntityBuilder = Types.EntityBuilder

type BuilderState = {
	Character: Model,
	Context: EntityContext,
	ComponentsToAdd: { [string]: { any } },
	ComponentsToExclude: { [string]: boolean },
	HooksToAdd: { string },
	ArchetypesConfig: { [string]: { string } }?,
}

type EntityBuilderInternal = EntityBuilder & {
	State: BuilderState,
}

local EntityBuilder = {}
EntityBuilder.__index = EntityBuilder

local ActiveArchetypes: { [string]: { string } }? = nil

function EntityBuilder.SetArchetypes(Archetypes: { [string]: { string } }?)
	ActiveArchetypes = Archetypes
end

function EntityBuilder.new(Character: Model, Context: EntityContext?): EntityBuilder
	local self: EntityBuilderInternal = setmetatable({
		State = {
			Character = Character,
			Context = Context or {},
			ComponentsToAdd = {},
			ComponentsToExclude = {},
			HooksToAdd = {},
			ArchetypesConfig = ActiveArchetypes,
		},
	}, EntityBuilder) :: any

	return self
end

function EntityBuilder:WithComponent(ComponentName: string, ...: any): EntityBuilder
	if not ComponentLoader.HasComponent(ComponentName) then
		error(string.format(Types.EngineName .. " Unknown component: '%s'", ComponentName))
	end

	self.State.ComponentsToAdd[ComponentName] = { ... }
	return self
end

function EntityBuilder:WithComponents(...: string): EntityBuilder
	for Index = 1, select("#", ...) do
		local ComponentName = select(Index, ...)
		self:WithComponent(ComponentName)
	end
	return self
end

function EntityBuilder:WithComponentsFromList(ComponentList: { string }): EntityBuilder
	for _, ComponentName in ComponentList do
		self:WithComponent(ComponentName)
	end
	return self
end

function EntityBuilder:WithArchetype(ArchetypeName: string): EntityBuilder
	if not self.State.ArchetypesConfig then
		error(Types.EngineName .. " No archetypes configured. Pass 'Archetypes' in Arch.Init()")
	end

	local ArchetypeComponents = self.State.ArchetypesConfig[ArchetypeName]
	if not ArchetypeComponents then
		error(string.format(Types.EngineName .. " Unknown archetype: '%s'", ArchetypeName))
	end

	for _, ComponentName in ArchetypeComponents do
		if ComponentName ~= "Core" then
			if ComponentLoader.HasComponent(ComponentName) then
				self.State.ComponentsToAdd[ComponentName] = {}
			end
		end
	end

	return self
end

function EntityBuilder:WithoutComponent(ComponentName: string): EntityBuilder
	self.State.ComponentsToExclude[ComponentName] = true
	self.State.ComponentsToAdd[ComponentName] = nil
	return self
end

function EntityBuilder:WithHook(HookName: string): EntityBuilder
	table.insert(self.State.HooksToAdd, HookName)
	return self
end

function EntityBuilder:WithHooks(HookNames: { string }?): EntityBuilder
	local LocalSelf = self :: EntityBuilderInternal -- This is necessary because of a bug in Roblox's type checker

	if not HookNames then
		return self
	end

	for _, HookName in HookNames do
		table.insert(LocalSelf.State.HooksToAdd, HookName)
	end

	return self
end

function EntityBuilder:Build(): Types.Entity
	local NewEntity = Entity.new(self.State.Character, self.State.Context)

	local ComponentNames = {}
	for ComponentName in self.State.ComponentsToAdd do
		if not self.State.ComponentsToExclude[ComponentName] then
			table.insert(ComponentNames, ComponentName)
		end
	end

	local OrderedComponents = ComponentLoader.ResolveDependencyOrder(ComponentNames)

	for _, ComponentName in OrderedComponents do
		local LoadedComponent = ComponentLoader.GetComponent(ComponentName)
		if not LoadedComponent then
			continue
		end

		local Args = self.State.ComponentsToAdd[ComponentName] or {}
		local ComponentInstance = LoadedComponent.Module.new(NewEntity, self.State.Context, table.unpack(Args))

		NewEntity:AddComponent(ComponentName, ComponentInstance)
	end

	for _, HookName in self.State.HooksToAdd do
		NewEntity.Hooks:RegisterHook(HookName)
	end

	NewEntity:FireCreated()

	return NewEntity
end

return EntityBuilder