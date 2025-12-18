--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local UpdateService = require(Shared.Networking.UpdateService)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)

local EntityUpdateSystem = {}

local EntityUpdateData: {
	[any]: {
		UpdateHandle: number?,
		ComponentAccumulators: { [string]: number },
	},
} = {}

local ComponentUpdateRates = {
	BodyFatigue = 1,
	Hunger = 1,
	Training = 1 / 10,
	Movement = 1 / 10,
	Sweat = 1 / 2,
	StatusEffect = 1 / 10,
}

local HEARTBEAT_UPDATE_INTERVAL = 1 / 30

local function UpdateEntity(EntityInstance: any, DeltaTime: number)
	if not EntityInstance.Character or not EntityInstance.Character.Parent then
		return
	end

	local UpdateData = EntityUpdateData[EntityInstance]
	if not UpdateData then
		return
	end

	for ComponentName, UpdateRate in ComponentUpdateRates do
		local Component = EntityInstance.Components[ComponentName]
		if Component and Component.Update then
			local Accumulator = UpdateData.ComponentAccumulators[ComponentName] or 0
			Accumulator += DeltaTime

			if Accumulator >= UpdateRate then
				Component:Update(Accumulator)
				UpdateData.ComponentAccumulators[ComponentName] = 0
			else
				UpdateData.ComponentAccumulators[ComponentName] = Accumulator
			end
		else
			UpdateData.ComponentAccumulators[ComponentName] = nil
		end
	end
end

EventBus.Subscribe(EntityEvents.ENTITY_CREATED, function(EventData)
	local EntityInstance = EventData.Entity
	if not EntityInstance.IsPlayer then
		return
	end

	EntityUpdateData[EntityInstance] = {
		UpdateHandle = nil,
		ComponentAccumulators = {},
	}

	local UpdateHandle = UpdateService.Register(function(DeltaTime: number)
		UpdateEntity(EntityInstance, DeltaTime)
	end, HEARTBEAT_UPDATE_INTERVAL)

	EntityUpdateData[EntityInstance].UpdateHandle = UpdateHandle
end)

EventBus.Subscribe(EntityEvents.ENTITY_DESTROYED, function(EventData)
	local EntityInstance = EventData.Entity
	local UpdateData = EntityUpdateData[EntityInstance]

	if UpdateData then
		if UpdateData.UpdateHandle then
			UpdateService.Disconnect(UpdateData.UpdateHandle)
		end

		table.clear(UpdateData.ComponentAccumulators)
	end

	EntityUpdateData[EntityInstance] = nil
end)

return EntityUpdateSystem
