--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local REPLICATION_THROTTLE = 0.05
local MAX_DISTANCE = 150

local LastReplicationTimesByVfxId: { [string]: number } = {}

local function ShouldReplicate(VfxId: string): boolean
	local NowTime = os.clock()
	local LastTime = LastReplicationTimesByVfxId[VfxId] or 0

	if NowTime - LastTime >= REPLICATION_THROTTLE then
		LastReplicationTimesByVfxId[VfxId] = NowTime
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

Packets.PlayVfx.OnServerEvent:Connect(function(Player: Player, VfxName: string, VfxData: any?)
	local Character = Player.Character
	if not Character then
		return
	end

	local VfxId = Player.UserId .. "_" .. VfxName
	if not ShouldReplicate(VfxId) then
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
		Packets.PlayVfxReplicate:FireClient(NearbyPlayer, SenderUserId, VfxName, VfxData)
	end
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	for VfxId in LastReplicationTimesByVfxId do
		if string.find(VfxId, tostring(Player.UserId)) then
			LastReplicationTimesByVfxId[VfxId] = nil
		end
	end
end)
