--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packets = require(Shared.Networking.Packets)

Packets.NetworkPing.OnClientEvent:Connect(function(SentServerTime: number)
	Packets.NetworkPong:Fire(SentServerTime)
end)