--!strict

local RunService = game:GetService("RunService")

local EventBus = require(script.Parent.Parent.Utilities.EventBus)
local ComponentLoader = require(script.Parent.Parent.Core.ComponentLoader)
local Types = require(script.Parent.Parent.Types)

type EntityUpdateData = {
	Entity: Types.Entity,
	ComponentAccumulators: { [string]: number },
}

type UpdateSystemState = {
	Entities: { [Types.Entity]: EntityUpdateData },
	ComponentUpdateRates: { [string]: number },
	HeartbeatConnection: RBXScriptConnection?,
	UpdateInterval: number,
}

local State: UpdateSystemState = {
	Entities = {},
	ComponentUpdateRates = {},
	HeartbeatConnection = nil,
	UpdateInterval = 1 / 30,
}

local UpdateSystem = {}

local function UpdateEntity(EntityData: EntityUpdateData, DeltaTime: number)
	local EntityInstance = EntityData.Entity

	if not EntityInstance.Character or not EntityInstance.Character.Parent then
		return
	end

	for ComponentName, UpdateRate in State.ComponentUpdateRates do
		local Component = EntityInstance:GetComponent(ComponentName)
		if not Component then
			continue
		end

		local ComponentTable = Component :: any
		if not ComponentTable.Update then
			continue
		end

		local Accumulator = EntityData.ComponentAccumulators[ComponentName] or 0
		Accumulator += DeltaTime

		if Accumulator >= UpdateRate then
			local Success, ErrorMessage = pcall(ComponentTable.Update, ComponentTable, Accumulator)
			if not Success then
				warn(string.format(Types.EngineName .. " Component '%s' update failed: %s", ComponentName, tostring(ErrorMessage)))
			end
			EntityData.ComponentAccumulators[ComponentName] = 0
		else
			EntityData.ComponentAccumulators[ComponentName] = Accumulator
		end
	end
end

local function OnHeartbeat(DeltaTime: number)
	for _, EntityData in pairs(State.Entities) do
		UpdateEntity(EntityData, DeltaTime)
	end
end

function UpdateSystem.Configure()
	local ComponentsWithUpdates = ComponentLoader.GetComponentsWithUpdates()

	for _, ComponentInfo in ComponentsWithUpdates do
		State.ComponentUpdateRates[ComponentInfo.Name] = ComponentInfo.Rate
	end
end

function UpdateSystem.Start()
	if State.HeartbeatConnection then
		return
	end

	EventBus.Subscribe("EntityCreated", function(EventData)
		local EntityInstance = EventData.Entity
		if not EntityInstance then
			return
		end

		State.Entities[EntityInstance] = {
			Entity = EntityInstance,
			ComponentAccumulators = {},
		}
	end)

	EventBus.Subscribe("EntityDestroyed", function(EventData)
		local EntityInstance = EventData.Entity
		if not EntityInstance then
			return
		end

		local EntityData = State.Entities[EntityInstance]
		if EntityData then
			table.clear(EntityData.ComponentAccumulators)
		end

		State.Entities[EntityInstance] = nil
	end)

	State.HeartbeatConnection = RunService.Heartbeat:Connect(OnHeartbeat)
end

function UpdateSystem.Stop()
	if State.HeartbeatConnection then
		State.HeartbeatConnection:Disconnect()
		State.HeartbeatConnection = nil
	end

	table.clear(State.Entities)
end

function UpdateSystem.SetUpdateRate(ComponentName: string, Rate: number)
	State.ComponentUpdateRates[ComponentName] = Rate
end

function UpdateSystem.GetUpdateRate(ComponentName: string): number?
	return State.ComponentUpdateRates[ComponentName]
end

function UpdateSystem.GetEntityCount(): number
	local Count = 0
	for _ in State.Entities do
		Count += 1
	end
	return Count
end

return UpdateSystem