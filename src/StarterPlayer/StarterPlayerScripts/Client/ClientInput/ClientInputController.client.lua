--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)

local PendingActions: { [string]: true } = {}

InputBuffer.OnAction(function(ActionName: string)
	Packets.PerformAction:Fire(ActionName)
end)

InputBuffer.OnRelease(function(ActionName: string)
	Packets.ReleaseAction:Fire(ActionName)
end)

Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
	PendingActions[ActionName] = nil
end)

Packets.ActionDenied.OnClientEvent:Connect(function(_Reason: string)
	table.clear(PendingActions)
end)