--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)
--local AnimationService = require(Shared.Services.AnimationService)
-- local SoundPlayer = require(Shared.General.SoundPlayer)
-- local VfxPlayer = require(Shared.VFX.VfxPlayer)

local PendingActions: { [string]: true } = {}
local CustomPredictions: { [string]: any } = {}

InputBuffer.OnAction(function(ActionName: string)
    Packets.PerformAction:Fire(ActionName)
end)

Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
    PendingActions[ActionName] = nil
end)

Packets.ActionDenied.OnClientEvent:Connect(function(_Reason: string)
    for ActionName in pairs(PendingActions) do
        local CustomPrediction = CustomPredictions[ActionName]
        if CustomPrediction and CustomPrediction["Rollback"] then
            CustomPrediction.Rollback()
        end
    end

    table.clear(PendingActions)
end)