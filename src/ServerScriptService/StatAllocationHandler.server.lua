--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterController = require(Server.Entity.Core.CharacterController)
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

local function IsTrainableStat(StatName: string): boolean
	for _, Stat in TRAINABLE_STATS do
		if Stat == StatName then
			return true
		end
	end
	return false
end

local function HandleAllocateStatPoint(Player: Player, StatName: string)
	if not IsTrainableStat(StatName) then
		warn("Player attempted to allocate invalid stat:", Player.Name, StatName)
		return
	end

	local Character = Player.Character
	if not Character then
		warn("Player has no character:", Player.Name)
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller then
		warn("Player character has no controller:", Player.Name)
		return
	end

	local TrainingController = Controller.TrainingController
	if not TrainingController then
		warn("Player has no training controller:", Player.Name)
		return
	end

	local Success = TrainingController:AllocateStatPoint(StatName)
	if not Success then
		warn("Player failed to allocate stat point:", Player.Name, StatName)
	end
end

Packets.AllocateStatPoint.OnServerEvent:Connect(HandleAllocateStatPoint)