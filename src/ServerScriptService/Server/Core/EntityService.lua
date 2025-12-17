--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Entity = require(Server.Entity.Core.Entity)
local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local DebugLogger = require(Shared.Debug.DebugLogger)

local EntityService = {}

local Entities: { [Model]: any } = {}

function EntityService.CreateEntity(Character: Model, Player: Player?, PlayerData: any?): any?
	if Entities[Character] then
		DebugLogger.Warning("EntityService", "Entity already exists for: %s", Character.Name)
		return Entities[Character]
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		DebugLogger.Error("EntityService", "No Humanoid found in: %s", Character.Name)
		return nil
	end

	local NewEntity = Entity.new({
		Character = Character,
		Humanoid = Humanoid,
		IsPlayer = Player ~= nil,
		Player = Player,
		PlayerData = PlayerData,
	})

	Entities[Character] = NewEntity

	DebugLogger.Info("EntityService", "Created entity for: %s", Character.Name)
	return NewEntity
end

function EntityService.GetEntity(Character: Model): any?
	return Entities[Character]
end

function EntityService.DestroyEntity(Character: Model)
	local EntityToDestroy = Entities[Character]
	if not EntityToDestroy then
		return
	end

	EntityToDestroy:Destroy()
	Entities[Character] = nil

	DebugLogger.Info("EntityService", "Destroyed entity for: %s", Character.Name)
end

function EntityService.GetAllEntities(): { any }
	local AllEntities = {}
	for _, EntityInstance in Entities do
		table.insert(AllEntities, EntityInstance)
	end
	return AllEntities
end

function EntityService.GetPlayerEntities(): { any }
	local PlayerEntities = {}
	for _, EntityInstance in Entities do
		if EntityInstance.IsPlayer then
			table.insert(PlayerEntities, EntityInstance)
		end
	end
	return PlayerEntities
end

EventBus.Subscribe(EntityEvents.ENTITY_DESTROYED, function(EventData)
	local Character = EventData.Character
	if Entities[Character] then
		Entities[Character] = nil
	end
end)

return EntityService
