--!strict

local EventBus = require(script.Parent.Parent.Utilities.EventBus)
local Types = require(script.Parent.Parent.Types)

type ModifierFunction = Types.ModifierFunction
type Modifier = Types.Modifier

type ModifierComponentInternal = Types.ModifierComponent & {
	Entity: any,
	ModifiersByType: { [string]: { Modifier } },
}

local ModifierComponent = {}
ModifierComponent.__index = ModifierComponent

function ModifierComponent.new(Entity: any): Types.ModifierComponent
	local self: ModifierComponentInternal = setmetatable({
		Entity = Entity,
		ModifiersByType = {},
	}, ModifierComponent) :: any

	return self
end

function ModifierComponent:Register(Type: string, Priority: number, ModifyFunction: ModifierFunction): () -> ()
	local Modifiers = self.ModifiersByType[Type]
	if not Modifiers then
		Modifiers = {}
		self.ModifiersByType[Type] = Modifiers
	end

	local NewModifier: Modifier = {
		Type = Type,
		Priority = Priority,
		ModifyFunction = ModifyFunction,
	}

	table.insert(Modifiers, NewModifier)

	table.sort(Modifiers, function(ModifierA, ModifierB)
		return ModifierA.Priority < ModifierB.Priority
	end)

	EventBus.Publish("ModifierAdded", {
		Entity = self.Entity,
		Character = self.Entity.Character,
		Type = Type,
		Priority = Priority,
	})

	return function()
		self:Unregister(Type, ModifyFunction)
	end
end

function ModifierComponent:Unregister(Type: string, ModifyFunction: ModifierFunction)
	local Modifiers = self.ModifiersByType[Type]
	if not Modifiers then
		return
	end

	for Index, ModifierEntry in ipairs(Modifiers) do
		if ModifierEntry.ModifyFunction == ModifyFunction then
			table.remove(Modifiers, Index)

			EventBus.Publish("ModifierRemoved", {
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

	local CurrentValue = BaseValue

	for _, ModifierEntry in ipairs(Modifiers) do
		CurrentValue = ModifierEntry.ModifyFunction(CurrentValue, Data)
	end

	return CurrentValue
end

function ModifierComponent:GetCount(Type: string): number
	local Modifiers = self.ModifiersByType[Type]
	return if Modifiers then #Modifiers else 0
end

function ModifierComponent:Clear(Type: string?)
	if Type then
		local Modifiers = self.ModifiersByType[Type]
		if Modifiers then
			for _ = #Modifiers, 1, -1 do
				EventBus.Publish("ModifierRemoved", {
					Entity = self.Entity,
					Character = self.Entity.Character,
					Type = Type,
				})
			end
			self.ModifiersByType[Type] = nil
		end
	else
		for ModifierType, Modifiers in self.ModifiersByType do
			for _ = #Modifiers, 1, -1 do
				EventBus.Publish("ModifierRemoved", {
					Entity = self.Entity,
					Character = self.Entity.Character,
					Type = ModifierType,
				})
			end
		end
		table.clear(self.ModifiersByType)
	end
end

function ModifierComponent:Destroy()
	table.clear(self.ModifiersByType)
end

return ModifierComponent