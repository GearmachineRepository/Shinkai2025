--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)

local ClanData = require(Shared.Configurations.Data.ClanData)
local TraitData = require(Shared.Configurations.Data.TraitData)

local StaminaComponent = require(Server.Entity.Components.StaminaComponent)
local HungerComponent = require(Server.Entity.Components.HungerComponent)
local BodyFatigueComponent = require(Server.Entity.Components.BodyFatigueComponent)
local TrainingComponent = require(Server.Entity.Components.TrainingComponent)
local BodyScalingComponent = require(Server.Entity.Components.BodyScalingComponent)
local SweatComponent = require(Server.Entity.Components.SweatComponent)
local InventoryComponent = require(Server.Entity.Components.InventoryComponent)
local ToolComponent = require(Server.Entity.Components.ToolComponent)
local HookComponent = require(Server.Entity.Components.HookComponent)

local ComponentInitializer = {}

EventBus.Subscribe(EntityEvents.ENTITY_CREATED, function(EventData)
	local Entity = EventData.Entity
	local IsPlayer = EventData.IsPlayer
	local PlayerData = EventData.PlayerData

	if not IsPlayer then
		return
	end

	local Stamina = StaminaComponent.new(Entity)
	Entity.Components.Stamina = Stamina
	Entity.Maid:GiveTask(Stamina)

	local Hunger = HungerComponent.new(Entity)
	Entity.Components.Hunger = Hunger
	Entity.Maid:GiveTask(Hunger)

	local BodyFatigue = BodyFatigueComponent.new(Entity, PlayerData)
	Entity.Components.BodyFatigue = BodyFatigue
	Entity.Maid:GiveTask(BodyFatigue)

	local Training = TrainingComponent.new(Entity, PlayerData)
	Entity.Components.Training = Training
	Entity.Maid:GiveTask(Training)

	local BodyScaling = BodyScalingComponent.new(Entity)
	Entity.Components.BodyScaling = BodyScaling
	Entity.Maid:GiveTask(BodyScaling)

	local Sweat = SweatComponent.new(Entity)
	Entity.Components.Sweat = Sweat
	Entity.Maid:GiveTask(Sweat)

	local Inventory = InventoryComponent.new(Entity, PlayerData)
	Entity.Components.Inventory = Inventory
	Entity.Maid:GiveTask(Inventory)

	local Tool = ToolComponent.new(Entity)
	Entity.Components.Tool = Tool
	Entity.Maid:GiveTask(Tool)

	local Hook = HookComponent.new(Entity)
	Entity.Components.Hook = Hook
	Entity.Maid:GiveTask(Hook)

	if PlayerData.Hooks then
		for _, HookName in PlayerData.Hooks do
			Hook:RegisterHook(HookName)
		end
	end

	if PlayerData.Traits then
		for _, TraitName in PlayerData.Traits do
			local Trait = TraitData.Definitions[TraitName]
			if Trait and Trait.Hooks and Entity.Components.Hook then
				for _, HookName in Trait.Hooks do
					Entity.Components.Hook:RegisterHook(HookName)
				end
			end
		end
	end

	if PlayerData.Clan and PlayerData.Clan.ClanName then
		local Clan = ClanData[PlayerData.Clan.ClanName]
		if Clan and Clan.Hooks and Entity.Components.Hook then
			for _, HookName in Clan.Hooks do
				Entity.Components.Hook:RegisterHook(HookName)
			end
		end
	end
end)

return ComponentInitializer
