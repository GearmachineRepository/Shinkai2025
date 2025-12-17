--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterController = require(Server.Entity.Core.CharacterController)
local DebugLogger = require(Shared.Debug.DebugLogger)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Packets = require(Shared.Networking.Packets)

local TRAINABLE_STATS = {
	StatTypes.DURABILITY,
	StatTypes.RUN_SPEED,
	StatTypes.STRIKING_POWER,
	StatTypes.STRIKE_SPEED,
	StatTypes.MUSCLE,
	StatTypes.MAX_STAMINA,
}

local RATE_LIMIT_WINDOW = 0.5
local LastAllocationTimes: { [number]: number } = {}

local function IsTrainableStat(StatName: string): boolean
	for _, Stat in TRAINABLE_STATS do
		if Stat == StatName then
			return true
		end
	end
	return false
end

local function IsRateLimited(UserId: number): boolean
	local Now = tick()
	local LastTime = LastAllocationTimes[UserId] or 0

	if Now - LastTime < RATE_LIMIT_WINDOW then
		return true
	end

	LastAllocationTimes[UserId] = Now
	return false
end

local function HandleAllocateStatPoint(Player: Player, StatName: string)
	if IsRateLimited(Player.UserId) then
		DebugLogger.Warning("StatAllocationHandler", "Rate limited: %s", Player.Name)
		return
	end

	if not IsTrainableStat(StatName) then
		DebugLogger.Warning("StatAllocationHandler", "Invalid stat from %s: %s", Player.Name, StatName)
		return
	end

	local Character = Player.Character
	if not Character then
		DebugLogger.Warning("StatAllocationHandler", "No character: %s", Player.Name)
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller then
		DebugLogger.Warning("StatAllocationHandler", "No controller: %s", Player.Name)
		return
	end

	local TrainingController = Controller.TrainingController
	if not TrainingController then
		DebugLogger.Warning("StatAllocationHandler", "No TrainingController: %s", Player.Name)
		return
	end

	local Success = TrainingController:AllocateStatPoint(StatName)
	if Success then
		DebugLogger.Info("StatAllocationHandler", "%s allocated point to %s", Player.Name, StatName)
	else
		DebugLogger.Info("StatAllocationHandler", "%s failed to allocate %s", Player.Name, StatName)
	end
end

Packets.AllocateStatPoint.OnServerEvent:Connect(HandleAllocateStatPoint)

game:GetService("Players").PlayerRemoving:Connect(function(Player: Player)
	LastAllocationTimes[Player.UserId] = nil
end)
