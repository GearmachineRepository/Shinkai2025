--!strict

-- ADDING IN THE FUTURE WITH NPCS

local ComponentRegistry = {}

export type EntityTypeConfig = {
	BaseComponents: { string },
	OptionalComponents: { string },
}

local EntityTypes: { [string]: EntityTypeConfig } = {}

function ComponentRegistry.RegisterEntityType(TypeName: string, Config: EntityTypeConfig)
	EntityTypes[TypeName] = Config
end

function ComponentRegistry.GetEntityType(TypeName: string): EntityTypeConfig?
	return EntityTypes[TypeName]
end

function ComponentRegistry.IsComponentAllowed(TypeName: string, ComponentName: string): boolean
	local Config = EntityTypes[TypeName]
	if not Config then
		return false
	end

	if table.find(Config.BaseComponents, ComponentName) then
		return true
	end

	if table.find(Config.OptionalComponents, ComponentName) then
		return true
	end

	return false
end

function ComponentRegistry.GetBaseComponents(TypeName: string): { string }
	local Config = EntityTypes[TypeName]
	return if Config then Config.BaseComponents else {}
end

ComponentRegistry.RegisterEntityType("Player", {
	BaseComponents = { "States", "Stats", "Modifiers" },
	OptionalComponents = {
		"Stamina",
		"Hunger",
		"BodyFatigue",
		"Training",
		"BodyScaling",
		"Sweat",
		"Inventory",
		"Tool",
		"Hook",
		"Movement",
	},
})

ComponentRegistry.RegisterEntityType("NPC", {
	BaseComponents = { "States", "Stats", "Modifiers" },
	OptionalComponents = {
		"Movement",
		"Combat",
		"AI",
	},
})

return ComponentRegistry
