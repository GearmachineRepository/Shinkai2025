--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(ReplicatedStorage.Shared.Events.EntityEvents)

export type ModifierFunction = (BaseValue: number, Data: { [string]: any }?) -> number

export type Modifier = {
	Type: string,
	Priority: number,
	ModifyFunction: ModifierFunction,
}

export type ModifierComponent = {
	Entity: any,

	Register: (self: ModifierComponent, Type: string, Priority: number, ModifyFunction: ModifierFunction) -> (),
	Unregister: (self: ModifierComponent, Type: string, ModifyFunction: ModifierFunction) -> (),
	Apply: (self: ModifierComponent, Type: string, BaseValue: number, Data: { [string]: any }?) -> number,
	GetCount: (self: ModifierComponent, Type: string) -> number,
	Clear: (self: ModifierComponent, Type: string?) -> (),
	Destroy: (self: ModifierComponent) -> (),
}

type ModifierComponentInternal = ModifierComponent & {
	ModifiersByType: { [string]: { Modifier } },
}

local ModifierComponent = {}
ModifierComponent.__index = ModifierComponent

function ModifierComponent.new(Entity: any): ModifierComponent
	local self: ModifierComponentInternal = setmetatable({
		Entity = Entity,
		ModifiersByType = {},
	}, ModifierComponent) :: any

	return self
end

function ModifierComponent:Register(Type: string, Priority: number, ModifyFunction: ModifierFunction)
	local Modifiers = self.ModifiersByType[Type]
	if not Modifiers then
		Modifiers = {}
		self.ModifiersByType[Type] = Modifiers
	end

	table.insert(Modifiers, {
		Type = Type,
		Priority = Priority,
		ModifyFunction = ModifyFunction,
	})

	table.sort(Modifiers, function(ModifierA, ModifierB)
		return ModifierA.Priority < ModifierB.Priority
	end)

	EventBus.Publish(EntityEvents.MODIFIER_ADDED, {
		Entity = self.Entity,
		Character = self.Entity.Character,
		Type = Type,
		Priority = Priority,
	})
end

function ModifierComponent:Unregister(Type: string, ModifyFunction: ModifierFunction)
	local Modifiers = self.ModifiersByType[Type]
	if not Modifiers then
		return
	end

	for Index, Modifier in ipairs(Modifiers) do
		if Modifier.ModifyFunction == ModifyFunction then
			table.remove(Modifiers, Index)

			EventBus.Publish(EntityEvents.MODIFIER_REMOVED, {
				Entity = self.Entity,
				Character = self.Entity.Character,
				Type = Type,
			})
			break
		end
	end
end

function ModifierComponent:Apply(Type: string, BaseValue: number, Data: { [string]: any }?): number
	local Modifiers = self.ModifiersByType[Type]
	if not Modifiers or #Modifiers == 0 then
		return BaseValue
	end

	local Result = BaseValue
	for _, Modifier in ipairs(Modifiers) do
		Result = Modifier.ModifyFunction(Result, Data or {})
	end

	return Result
end

function ModifierComponent:GetCount(Type: string): number
	local Modifiers = self.ModifiersByType[Type]
	return if Modifiers then #Modifiers else 0
end

function ModifierComponent:Clear(Type: string?)
	if Type then
		self.ModifiersByType[Type] = nil
	else
		table.clear(self.ModifiersByType)
	end
end

function ModifierComponent:Destroy()
	table.clear(self.ModifiersByType)
end

return ModifierComponent
