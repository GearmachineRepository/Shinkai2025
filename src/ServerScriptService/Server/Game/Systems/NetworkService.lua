--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local PING_INTERVAL_SECONDS = 1.0
local EMA_ALPHA = 0.2
local MAX_RTT_SECONDS = 5.0

type PlayerNetworkState = {
	SmoothedRttSeconds: number,
	HasSample: boolean,

	LastPingId: number,
	LastPingSentServerTime: number,
	HasOutstandingPing: boolean,
}

local NetworkService = {}

local PlayerStates: { [Player]: PlayerNetworkState } = {}

local function GetOrCreatePlayerState(Player: Player): PlayerNetworkState
	local ExistingState = PlayerStates[Player]
	if ExistingState then
		return ExistingState
	end

	local NewState: PlayerNetworkState = {
		SmoothedRttSeconds = 0,
		HasSample = false,

		LastPingId = 0,
		LastPingSentServerTime = 0,
		HasOutstandingPing = false,
	}

	PlayerStates[Player] = NewState
	return NewState
end

function NetworkService.GetPingMs(Player: Player): number
	local State = PlayerStates[Player]
	if not State or not State.HasSample then
		return -1
	end

	return (State.SmoothedRttSeconds * 1000) * 0.5
end

function NetworkService.GetRttMs(Player: Player): number
	local State = PlayerStates[Player]
	if not State or not State.HasSample then
		return -1
	end

	return State.SmoothedRttSeconds * 1000
end

Packets.NetworkPong.OnServerEvent:Connect(function(Player: Player, PingId: number)
	local State = PlayerStates[Player]
	if not State or not State.HasOutstandingPing then
		return
	end

	if PingId ~= State.LastPingId then
		return
	end

	local NowTime = workspace:GetServerTimeNow()
	local RttSeconds = NowTime - State.LastPingSentServerTime
	State.HasOutstandingPing = false

	if RttSeconds < 0 then
		return
	end

	if RttSeconds > MAX_RTT_SECONDS then
		warn(
			"[Network] RTT unusually high (" ..
			string.format("%.2f", RttSeconds) ..
			"s) for " .. Player.Name
		)
		return
	end

	if not State.HasSample then
		State.SmoothedRttSeconds = RttSeconds
		State.HasSample = true
		return
	end

	State.SmoothedRttSeconds = (State.SmoothedRttSeconds * (1 - EMA_ALPHA)) + (RttSeconds * EMA_ALPHA)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	PlayerStates[Player] = nil
end)

task.spawn(function()
	while true do
		local NowTime = workspace:GetServerTimeNow()

		for _, Player in Players:GetPlayers() do
			local State = GetOrCreatePlayerState(Player)

			local NextPingId = State.LastPingId + 1
			State.LastPingId = NextPingId
			State.LastPingSentServerTime = NowTime
			State.HasOutstandingPing = true

			Packets.NetworkPing:FireClient(Player, NextPingId)
		end

		task.wait(PING_INTERVAL_SECONDS)
	end
end)

return NetworkService
