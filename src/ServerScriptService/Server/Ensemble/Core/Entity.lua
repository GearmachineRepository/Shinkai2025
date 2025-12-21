--!strict

local Maid = require(script.Parent.Parent.Utilities.Maid)
local EventBus = require(script.Parent.Parent.Utilities.EventBus)
local StateComponent = require(script.Parent.Parent.Components.StateComponent)
local StatComponent = require(script.Parent.Parent.Components.StatComponent)
local ModifierComponent = require(script.Parent.Parent.Components.ModifierComponent)
local HookComponent = require(script.Parent.Parent.Components.HookComponent)
local Types = require(script.Parent.Parent.Types)

type EntityContext = Types.EntityContext

type EntityInternal = Types.Entity & {
	Maid: Types.Maid,
	Components: { [string]: any },
	Destroyed: boolean,
}

local Entity = {}
Entity.__index = Entity

local EntityRegistry: { [Model]: Types.Entity } = {}

function Entity.GetEntity(Character: Model): Types.Entity?
	return EntityRegistry[Character]
end

function Entity.GetAllEntities(): { Types.Entity }
	local Entities = {}
	for _, EntityInstance in pairs(EntityRegistry) do
		table.insert(Entities, EntityInstance)
	end
	return Entities
end

function Entity.new(Character: Model, Context: EntityContext): Types.Entity
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		error(string.format(Types.EngineName .. " Character '%s' has no Humanoid", Character.Name))
	end

	if EntityRegistry[Character] then
		error(string.format(Types.EngineName .. " Entity already exists for character '%s'", Character.Name))
	end

	local self: EntityInternal = setmetatable({
		Character = Character,
		Humanoid = Humanoid,
		IsPlayer = Context.Player ~= nil,
		Player = Context.Player,
		Context = Context,

		Maid = Maid.new(),
		Components = {},
		Destroyed = false,

		States = nil :: any,
		Stats = nil :: any,
		Modifiers = nil :: any,
		Hooks = nil :: any,
	}, Entity) :: any

	local InitialStats = Context.Data and Context.Data.Stats or nil

	self.States = StateComponent.new(self)
	self.Stats = StatComponent.new(self, InitialStats)
	self.Modifiers = ModifierComponent.new(self)
	self.Hooks = HookComponent.new(self)

	self.Components.States = self.States
	self.Components.Stats = self.Stats
	self.Components.Modifiers = self.Modifiers
	self.Components.Hooks = self.Hooks

	self.Maid:GiveTask(self.States)
	self.Maid:GiveTask(self.Stats)
	self.Maid:GiveTask(self.Modifiers)
	self.Maid:GiveTask(self.Hooks)

	Character:SetAttribute("HasEntity", true)
	EntityRegistry[Character] = self

	self.Maid:GiveTask(Humanoid.HealthChanged:Connect(function()
		if not self.Destroyed then
			self.Stats:SetStat("Health", Humanoid.Health)
		end
	end))

	return self
end

function Entity:AddComponent(ComponentName: string, ComponentInstance: any)
	if self.Components[ComponentName] then
		warn(string.format(Types.EngineName .. " Component '%s' already exists on entity", ComponentName))
		return
	end

	self.Components[ComponentName] = ComponentInstance
	self.Maid:GiveTask(ComponentInstance)
end

function Entity:GetComponent<T>(ComponentName: string): T?
	return self.Components[ComponentName] :: T?
end

function Entity:HasComponent(ComponentName: string): boolean
	return self.Components[ComponentName] ~= nil
end

function Entity:FireCreated()
	EventBus.Publish("EntityCreated", {
		Entity = self,
		Character = self.Character,
		IsPlayer = self.IsPlayer,
		Player = self.Player,
		Context = self.Context,
	})
end

function Entity:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true

	EventBus.Publish("EntityDestroyed", {
		Entity = self,
		Character = self.Character,
	})

	if self.Character then
		self.Character:SetAttribute("HasEntity", nil)
		EntityRegistry[self.Character] = nil
	end

	self.Maid:DoCleaning()
	table.clear(self.Components)
end

return Entity