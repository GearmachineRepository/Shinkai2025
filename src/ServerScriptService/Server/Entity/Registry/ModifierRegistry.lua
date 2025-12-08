--!strict

local ModifierRegistry = {}
ModifierRegistry.__index = ModifierRegistry

export type ModifierFunction = (Value: any, Data: any?) -> any

export type ModifierEntry = {
	Priority: number,
	Modifier: ModifierFunction,
}

export type ModifierRegistry = typeof(setmetatable({} :: {
	Registries: {[string]: {ModifierEntry}},
}, ModifierRegistry))

local VALID_TYPES = {
	Attack = true,
	Damage = true,
	Speed = true,
	StrikeSpeed = true,
	Healing = true,
	StaminaCost = true,
	MaxHealth = true,
}

function ModifierRegistry.new(): ModifierRegistry
	local self = setmetatable({
		Registries = {},
	}, ModifierRegistry)

	for ModifierType in VALID_TYPES do
		self.Registries[ModifierType] = {}
	end

	return self
end

function ModifierRegistry:Register(ModifierType: string, Priority: number, Modifier: ModifierFunction): () -> ()
	if not VALID_TYPES[ModifierType] then
		warn("[ModifierRegistry] Invalid modifier type:", ModifierType)
		return function() end
	end

	local Entry: ModifierEntry = {
		Priority = Priority,
		Modifier = Modifier,
	}

	table.insert(self.Registries[ModifierType], Entry)

	table.sort(self.Registries[ModifierType], function(A, B)
		return A.Priority > B.Priority
	end)

	return function()
		self:Unregister(ModifierType, Entry)
	end
end

function ModifierRegistry:Unregister(ModifierType: string, Entry: ModifierEntry)
	local Registry = self.Registries[ModifierType]
	if not Registry then
		return
	end

	local Index = table.find(Registry, Entry)
	if Index then
		table.remove(Registry, Index)
	end
end

function ModifierRegistry:Apply(ModifierType: string, BaseValue: any, Data: any?): any
	local Registry = self.Registries[ModifierType]
	if not Registry then
		warn("[ModifierRegistry] Invalid modifier type:", ModifierType)
		return BaseValue
	end

	local ModifiedValue = BaseValue

	for _, Entry in Registry do
		ModifiedValue = Entry.Modifier(ModifiedValue, Data)
	end

	return ModifiedValue
end

function ModifierRegistry:GetCount(ModifierType: string): number
	local Registry = self.Registries[ModifierType]
	if not Registry then
		return 0
	end

	return #Registry
end

function ModifierRegistry:Clear(ModifierType: string?)
	if ModifierType then
		if self.Registries[ModifierType] then
			table.clear(self.Registries[ModifierType])
		end
	else
		for Type in VALID_TYPES do
			table.clear(self.Registries[Type])
		end
	end
end

function ModifierRegistry:Destroy()
	for Type in VALID_TYPES do
		table.clear(self.Registries[Type])
	end
end

return ModifierRegistry