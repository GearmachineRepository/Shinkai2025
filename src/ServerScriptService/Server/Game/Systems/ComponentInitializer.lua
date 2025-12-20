--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)

local ClanData = require(Shared.Configurations.Data.ClanData)
local TraitData = require(Shared.Configurations.Data.TraitData)

local GameComponents = Server.Game.Components
local BaseComponents = Server.Framework.BaseComponents

local StaminaComponent = require(GameComponents.StaminaComponent)
local HungerComponent = require(GameComponents.HungerComponent)
local BodyFatigueComponent = require(GameComponents.BodyFatigueComponent)
local TrainingComponent = require(GameComponents.TrainingComponent)
local BodyScalingComponent = require(GameComponents.BodyScalingComponent)
local SweatComponent = require(GameComponents.SweatComponent)
local InventoryComponent = require(GameComponents.InventoryComponent)
local ToolComponent = require(GameComponents.ToolComponent)
local HookComponent = require(BaseComponents.HookComponent)
local MovementComponent = require(GameComponents.MovementComponent)
local StatusEffectComponent = require(GameComponents.StatusEffectComponent)

local ComponentInitializer = {}

local function AddComponent(Entity: any, ComponentName: string, Component: any)
	Entity.Components[ComponentName] = Component
	Entity.Maid:GiveTask(Component)
end

EventBus.Subscribe(EntityEvents.ENTITY_CREATED, function(EventData)
	local Entity = EventData.Entity
	local IsPlayer = EventData.IsPlayer
	local PlayerData = EventData.PlayerData

	if not IsPlayer then
		return
	end

	AddComponent(Entity, "Stamina", StaminaComponent.new(Entity))
	AddComponent(Entity, "Hunger", HungerComponent.new(Entity))
	AddComponent(Entity, "BodyFatigue", BodyFatigueComponent.new(Entity, PlayerData))
	AddComponent(Entity, "Training", TrainingComponent.new(Entity, PlayerData))
	AddComponent(Entity, "BodyScaling", BodyScalingComponent.new(Entity))
	AddComponent(Entity, "Sweat", SweatComponent.new(Entity))
	AddComponent(Entity, "Inventory", InventoryComponent.new(Entity, PlayerData))
	AddComponent(Entity, "Tool", ToolComponent.new(Entity))
	AddComponent(Entity, "Hook", HookComponent.new(Entity))
	AddComponent(Entity, "Movement", MovementComponent.new(Entity))
	AddComponent(Entity, "StatusEffect", StatusEffectComponent.new(Entity))

	if PlayerData.Hooks then
		for _, HookName in PlayerData.Hooks do
			Entity.Components.Hook:RegisterHook(HookName)
		end
	end

	if PlayerData.Traits then
		for _, TraitName in PlayerData.Traits do
			local Trait = TraitData.Definitions[TraitName]
			if Trait and Trait.Hooks then
				for _, HookName in Trait.Hooks do
					Entity.Components.Hook:RegisterHook(HookName)
				end
			end
		end
	end

	if PlayerData.Clan and PlayerData.Clan.ClanName then
		local Clan = ClanData[PlayerData.Clan.ClanName]
		if Clan and Clan.Hooks then
			for _, HookName in Clan.Hooks do
				Entity.Components.Hook:RegisterHook(HookName)
			end
		end
	end
end)

return ComponentInitializer
