--!strict

local Types = require(script.Types)
local Maid = require(script.Utilities.Maid)
local Signal = require(script.Utilities.Signal)
local EventBus = require(script.Utilities.EventBus)

local StateSchema = require(script.Schemas.StateSchema)
local StatSchema = require(script.Schemas.StatSchema)
local EventSchema = require(script.Schemas.EventSchema)

local StateComponent = require(script.Components.StateComponent)
local StatComponent = require(script.Components.StatComponent)
local HookComponent = require(script.Components.HookComponent)

local Entity = require(script.Core.Entity)
local EntityBuilder = require(script.Core.EntityBuilder)
local ComponentLoader = require(script.Core.ComponentLoader)
local HookLoader = require(script.Core.HookLoader)

local UpdateSystem = require(script.Systems.UpdateSystem)
local HookHelpers = require(script.Helpers.HookHelpers)

type InitConfig = Types.InitConfig
type EntityContext = Types.EntityContext
type EntityBuilder = Types.EntityBuilder
type EngineConfigs = Types.EngineConfigs

local Arch = {}

local Initialized = false

local function FormatValidationErrors(Errors: { Types.ValidationError }): string
	local Lines = {}
	for _, Error in Errors do
		table.insert(Lines, string.format("  - %s: %s", Error.Field, Error.Message))
	end
	return table.concat(Lines, "\n")
end

local function ValidateConfigs(Configs: EngineConfigs)
	local StateResult = StateSchema.Validate(Configs.States)
	if not StateResult.Valid then
		error(string.format("[Arch] State config validation failed:\n%s", FormatValidationErrors(StateResult.Errors)))
	end

	local StatResult = StatSchema.Validate(Configs.Stats)
	if not StatResult.Valid then
		error(string.format("[Arch] Stat config validation failed:\n%s", FormatValidationErrors(StatResult.Errors)))
	end

	local EventResult = EventSchema.Validate(Configs.Events)
	if not EventResult.Valid then
		error(string.format("[Arch] Event config validation failed:\n%s", FormatValidationErrors(EventResult.Errors)))
	end
end

function Arch.Init(Config: InitConfig)
	if Initialized then
		error("[Arch] Engine already initialized")
	end

	if not Config.Components then
		error("[Arch] Config.Components folder is required")
	end

	if not Config.Hooks then
		error("[Arch] Config.Hooks folder is required")
	end

	if not Config.Configs then
		error("[Arch] Config.Configs is required")
	end

	if not Config.Configs.States then
		error("[Arch] Config.Configs.States is required")
	end

	if not Config.Configs.Stats then
		error("[Arch] Config.Configs.Stats is required")
	end

	if not Config.Configs.Events then
		error("[Arch] Config.Configs.Events is required")
	end

	ValidateConfigs(Config.Configs)

	EventBus.Configure(Config.Configs.Events)
	StateComponent.SetConfig(Config.Configs.States)
	StatComponent.SetConfig(Config.Configs.Stats)

	ComponentLoader.Configure(Config.Components)
	HookLoader.Configure(Config.Hooks)

	HookComponent.SetHookLoader(HookLoader)

	if Config.Archetypes then
		EntityBuilder.SetArchetypes(Config.Archetypes)
	end

	UpdateSystem.Configure()
	UpdateSystem.Start()

	Initialized = true

	print("[Arch] Engine initialized successfully")
	print(string.format("  Components: %d", #ComponentLoader.GetAllComponentNames()))
	print(string.format("  Hooks: %d", #HookLoader.GetAllHookNames()))
end

function Arch.CreateEntity(Character: Model, Context: EntityContext?): EntityBuilder
	if not Initialized then
		error("[Arch] Engine not initialized. Call Arch.Init() first")
	end

	return EntityBuilder.new(Character, Context or {})
end

function Arch.GetEntity(Character: Model): Types.Entity?
	return Entity.GetEntity(Character)
end

function Arch.GetAllEntities(): { Types.Entity }
	return Entity.GetAllEntities()
end

function Arch.DestroyEntity(Character: Model)
	local EntityInstance = Entity.GetEntity(Character)
	if EntityInstance then
		EntityInstance:Destroy()
	end
end

Arch.Maid = Maid
Arch.Signal = Signal
Arch.Events = EventBus
Arch.HookHelpers = HookHelpers
Arch.Types = Types

Arch.ComponentLoader = ComponentLoader
Arch.HookLoader = HookLoader

return Arch