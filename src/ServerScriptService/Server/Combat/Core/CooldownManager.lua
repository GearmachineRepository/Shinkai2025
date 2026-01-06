--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local Packets = require(Shared.Networking.Packets)

type Entity = CombatTypes.Entity

local CooldownManager = {}

local EntityCooldowns: { [Entity]: { [string]: number } } = {}

local function NotifyClient(Entity: Entity, CooldownId: string, Duration: number)
	if not Entity.Player then
		return
	end

	local StartTime = workspace:GetServerTimeNow()
	Packets.StartCooldown:FireClient(Entity.Player, CooldownId, StartTime, Duration)
end

function CooldownManager.Start(Entity: Entity, CooldownId: string, Duration: number)
	if Duration <= 0 then
		return
	end

	EntityCooldowns[Entity] = EntityCooldowns[Entity] or {}
	EntityCooldowns[Entity][CooldownId] = workspace:GetServerTimeNow()

	NotifyClient(Entity, CooldownId, Duration)
end

function CooldownManager.Clear(Entity: Entity, CooldownId: string)
	local Cooldowns = EntityCooldowns[Entity]
	if Cooldowns then
		Cooldowns[CooldownId] = nil
	end

	if Entity.Player then
		Packets.ClearCooldown:FireClient(Entity.Player, CooldownId)
	end
end

function CooldownManager.IsOnCooldown(Entity: Entity, CooldownId: string, Duration: number): boolean
	local Cooldowns = EntityCooldowns[Entity]
	if not Cooldowns then
		return false
	end

	local LastTime = Cooldowns[CooldownId]
	if not LastTime then
		return false
	end

	return (workspace:GetServerTimeNow() - LastTime) < Duration
end

function CooldownManager.GetRemaining(Entity: Entity, CooldownId: string, Duration: number): number
	local Cooldowns = EntityCooldowns[Entity]
	if not Cooldowns then
		return 0
	end

	local LastTime = Cooldowns[CooldownId]
	if not LastTime then
		return 0
	end

	local Elapsed = workspace:GetServerTimeNow() - LastTime
	local Remaining = Duration - Elapsed

	return math.max(0, Remaining)
end

function CooldownManager.GetElapsed(Entity: Entity, CooldownId: string): number
	local Cooldowns = EntityCooldowns[Entity]
	if not Cooldowns then
		return 0
	end

	local LastTime = Cooldowns[CooldownId]
	if not LastTime then
		return 0
	end

	return workspace:GetServerTimeNow() - LastTime
end

function CooldownManager.ClearAll(Entity: Entity)
	local Cooldowns = EntityCooldowns[Entity]
	if not Cooldowns then
		return
	end

	if Entity.Player then
		for CooldownId in Cooldowns do
			Packets.ClearCooldown:FireClient(Entity.Player, CooldownId)
		end
	end

	EntityCooldowns[Entity] = nil
end

function CooldownManager.CleanupEntity(Entity: Entity)
	EntityCooldowns[Entity] = nil
end

return CooldownManager