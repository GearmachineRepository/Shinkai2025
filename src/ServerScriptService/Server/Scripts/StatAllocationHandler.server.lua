--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Entity = require(Server.Framework.Core.Entity)
local StatSystem = require(Server.Game.Systems.StatSystem)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
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
		return
	end

	if not IsTrainableStat(StatName) then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Training then
		return
	end

	local TrainingComponent = EntityInstance.Components.Training
	local PlayerData = TrainingComponent.PlayerData

	local Success, _ErrorMessage = StatSystem.AllocateStar(PlayerData, StatName)

	if not Success then
		return
	end

	local NewStars = PlayerData.Stats[StatName .. "_Stars"]
	local BaseValue = StatBalance.Defaults[StatName] or 0
	local NewStatValue = StatSystem.CalculateStatValue(BaseValue, NewStars, StatName)

	EntityInstance.Stats:SetStat(StatName, NewStatValue)

	Character:SetAttribute(StatName .. "_Stars", NewStars)

	StatSystem.UpdateAvailablePoints(PlayerData, StatName)
	local AvailablePoints = PlayerData.Stats[StatName .. "_AvailablePoints"]
	Character:SetAttribute(StatName .. "_AvailablePoints", AvailablePoints)

	-- DebugLogger.Info("StatAllocationHandler", "%s allocated point to %s", Player.Name, StatName)
end

Packets.AllocateStatPoint.OnServerEvent:Connect(HandleAllocateStatPoint)

game:GetService("Players").PlayerRemoving:Connect(function(Player: Player)
	LastAllocationTimes[Player.UserId] = nil
end)
