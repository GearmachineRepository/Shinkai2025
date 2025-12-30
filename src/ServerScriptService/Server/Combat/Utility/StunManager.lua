--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local StunManager = {}

local ActiveStuns: { [any]: thread } = {}

function StunManager.ApplyStun(Entity: any, Duration: number, Source: string?)
	if not Entity or not Entity.States then
		return
	end

	if ActiveStuns[Entity] then
		local Status = coroutine.status(ActiveStuns[Entity])
		if Status == "suspended" then
			task.cancel(ActiveStuns[Entity])
		end
	end

	Entity.States:SetState(StateTypes.STUNNED, true)

	Ensemble.Events.Publish(CombatEvents.StunApplied, {
		Entity = Entity,
		Duration = Duration,
		Source = Source,
	})

	local StunThread = task.delay(Duration, function()
		if Entity.States then
			Entity.States:SetState(StateTypes.STUNNED, false)
		end

		ActiveStuns[Entity] = nil

		Ensemble.Events.Publish(CombatEvents.StunRecovered, {
			Entity = Entity,
			Source = Source,
		})
	end)

	ActiveStuns[Entity] = StunThread
end

function StunManager.ClearStun(Entity: any)
	if not Entity or not Entity.States then
		return
	end

	if ActiveStuns[Entity] then
		local Status = coroutine.status(ActiveStuns[Entity])
		if Status == "suspended" then
			task.cancel(ActiveStuns[Entity])
		end
		ActiveStuns[Entity] = nil
	end

	Entity.States:SetState(StateTypes.STUNNED, false)
end

function StunManager.IsStunned(Entity: any): boolean
	if not Entity or not Entity.States then
		return false
	end

	return Entity.States:GetState(StateTypes.STUNNED)
end

function StunManager.CleanupEntity(Entity: any)
	if ActiveStuns[Entity] then
		local Status = coroutine.status(ActiveStuns[Entity])
		if Status == "suspended" then
			task.cancel(ActiveStuns[Entity])
		end
		ActiveStuns[Entity] = nil
	end
end

return StunManager