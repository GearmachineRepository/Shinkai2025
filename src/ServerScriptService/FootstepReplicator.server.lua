--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local REPLICATION_THROTTLE = 0.1
local MAX_DISTANCE = 150

local LastReplicationTimes: { [number]: number } = {}

local function ShouldReplicate(PlayerId: number): boolean
	local Now = os.clock()
	local Last = LastReplicationTimes[PlayerId] or 0

	if Now - Last >= REPLICATION_THROTTLE then
		LastReplicationTimes[PlayerId] = Now
		return true
	end

	return false
end

local function GetRootPosition(Character: Model): Vector3?
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return nil
	end
	return RootPart.Position
end

local function GetNearbyPlayers(SourcePlayer: Player, Position: Vector3): { Player }
	local Nearby: { Player } = {}

	for _, OtherPlayer in Players:GetPlayers() do
		if OtherPlayer == SourcePlayer then
			continue
		end

		local OtherCharacter = OtherPlayer.Character
		if not OtherCharacter then
			continue
		end

		local OtherPosition = GetRootPosition(OtherCharacter)
		if not OtherPosition then
			continue
		end

		if (OtherPosition - Position).Magnitude <= MAX_DISTANCE then
			table.insert(Nearby, OtherPlayer)
		end
	end

	return Nearby
end

Packets.Footplanted.OnServerEvent:Connect(function(Player: Player, MaterialId: number)
	if not ShouldReplicate(Player.UserId) then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local Position = GetRootPosition(Character)
	if not Position then
		return
	end

	local NearbyPlayers = GetNearbyPlayers(Player, Position)
	if #NearbyPlayers == 0 then
		return
	end

	for _, OtherPlayer in NearbyPlayers do
		Packets.Footplanted:FireClient(OtherPlayer, Player.UserId, MaterialId)
	end
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	LastReplicationTimes[Player.UserId] = nil
end)
