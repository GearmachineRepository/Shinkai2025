--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local MAX_DISTANCE = 150
local THROTTLE_RATE = 0.05

local LastReplicationTimes: { [string]: number } = {}

local function ShouldReplicate(Key: string): boolean
	local Now = os.clock()
	local LastTime = LastReplicationTimes[Key] or 0

	if Now - LastTime < THROTTLE_RATE then
		return false
	end

	LastReplicationTimes[Key] = Now
	return true
end

local function GetRootPosition(Character: Model): Vector3?
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return nil
	end
	return RootPart.Position
end

local function GetNearbyPlayers(SourcePlayer: Player, SourcePosition: Vector3): { Player }
	local NearbyPlayers: { Player } = {}

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

		if (OtherPosition - SourcePosition).Magnitude <= MAX_DISTANCE then
			table.insert(NearbyPlayers, OtherPlayer)
		end
	end

	return NearbyPlayers
end

local function Replicate(Player: Player, Key: string, FireCallback: (NearbyPlayer: Player, SenderId: number) -> ())
	if not ShouldReplicate(Key) then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local SourcePosition = GetRootPosition(Character)
	if not SourcePosition then
		return
	end

	local NearbyPlayers = GetNearbyPlayers(Player, SourcePosition)

	for _, NearbyPlayer in NearbyPlayers do
		FireCallback(NearbyPlayer, Player.UserId)
	end
end

Packets.Footplanted.OnServerEvent:Connect(function(Player: Player, MaterialId: number)
	Replicate(Player, Player.UserId .. "_Footstep", function(NearbyPlayer, SenderId)
		Packets.FootplantedReplicate:FireClient(NearbyPlayer, SenderId, MaterialId)
	end)
end)

Packets.PlaySound.OnServerEvent:Connect(function(Player: Player, SoundName: string, AdditionalData: any?)
	Replicate(Player, Player.UserId .. "_" .. SoundName, function(NearbyPlayer, SenderId)
		Packets.PlaySoundReplicate:FireClient(NearbyPlayer, SenderId, SoundName, AdditionalData)
	end)
end)

Packets.PlayVfx.OnServerEvent:Connect(function(Player: Player, VfxName: string, VfxData: any?)
	Replicate(Player, Player.UserId .. "_" .. VfxName, function(NearbyPlayer, SenderId)
		Packets.PlayVfxReplicate:FireClient(NearbyPlayer, SenderId, VfxName, VfxData)
	end)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	local Prefix = tostring(Player.UserId)

	for Key in LastReplicationTimes do
		if string.find(Key, Prefix, 1, true) then
			LastReplicationTimes[Key] = nil
		end
	end
end)