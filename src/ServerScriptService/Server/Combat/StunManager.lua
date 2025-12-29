--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)

local StunManager = {}

local StunEndTimes: { [any]: number } = {}
local ActiveTasks: { [any]: thread } = {}

function StunManager.ApplyStun(Entity: any, Duration: number, Reason: string?)
	local CurrentTime = workspace:GetServerTimeNow()
	local NewEndTime = CurrentTime + Duration
	local ExistingEndTime = StunEndTimes[Entity] or 0

	if NewEndTime <= ExistingEndTime then
		return
	end

	StunEndTimes[Entity] = NewEndTime
	Entity.States:SetState("Stunned", true)

	if ActiveTasks[Entity] then
		task.cancel(ActiveTasks[Entity])
	end

    Ensemble.Events.Publish(CombatEvents.HitStunApplied, {
		Entity = Entity,
		Target = Entity.Character,
		Duration = Duration,
        Reason = Reason,
	})

	ActiveTasks[Entity] = task.delay(Duration, function()
		if StunEndTimes[Entity] and workspace:GetServerTimeNow() >= StunEndTimes[Entity] then
			StunEndTimes[Entity] = nil
			ActiveTasks[Entity] = nil
			Entity.States:SetState("Stunned", false)

            Ensemble.Events.Publish(CombatEvents.StunEnded, {
                Entity = Entity,
                Target = Entity.Character,
                Reason = "HitStunExpired",
            })
		end
	end)
end

function StunManager.ClearStun(Entity: any)
	StunEndTimes[Entity] = nil

	if ActiveTasks[Entity] then
		task.cancel(ActiveTasks[Entity])
		ActiveTasks[Entity] = nil
	end

	Entity.States:SetState("Stunned", false)
end

function StunManager.GetRemainingStun(Entity: any): number
	local EndTime = StunEndTimes[Entity]
	if not EndTime then
		return 0
	end
	return math.max(0, EndTime - workspace:GetServerTimeNow())
end

function StunManager.CleanupEntity(Entity: any)
	StunEndTimes[Entity] = nil
	if ActiveTasks[Entity] then
		task.cancel(ActiveTasks[Entity])
		ActiveTasks[Entity] = nil
	end
end

return StunManager