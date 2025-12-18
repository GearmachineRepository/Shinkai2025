--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local REPLICATION_THROTTLE = 0.05
local MAX_DISTANCE = 150

local LastReplicationTimesBySoundId: { [string]: number } = {}

local function ShouldReplicate(SoundId: string): boolean
	local NowTime = os.clock()
	local LastTime = LastReplicationTimesBySoundId[SoundId] or 0

	if NowTime - LastTime >= REPLICATION_THROTTLE then
		LastReplicationTimesBySoundId[SoundId] = NowTime
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

Packets.PlaySound.OnServerEvent:Connect(function(Player: Player, SoundName: string, AdditionalData: any?)
	local Character = Player.Character
	if not Character then
		return
	end

	local SoundId = Player.UserId .. "_" .. SoundName
	if not ShouldReplicate(SoundId) then
		return
	end

	local SourcePosition = GetRootPosition(Character)
	if not SourcePosition then
		return
	end

	local NearbyPlayers = GetNearbyPlayers(Player, SourcePosition)
	if #NearbyPlayers == 0 then
		return
	end

	local SenderUserId = Player.UserId

	for _, NearbyPlayer in NearbyPlayers do
		Packets.PlaySoundReplicate:FireClient(NearbyPlayer, SenderUserId, SoundName, AdditionalData)
	end
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	for SoundId in LastReplicationTimesBySoundId do
		if string.find(SoundId, tostring(Player.UserId)) then
			LastReplicationTimesBySoundId[SoundId] = nil
		end
	end
end)
