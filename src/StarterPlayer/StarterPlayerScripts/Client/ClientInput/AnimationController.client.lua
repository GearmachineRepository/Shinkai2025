--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local AnimationService = require(Shared.Services.AnimationService)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

local Player = Players.LocalPlayer

local function PreloadAllAnimations()
    local AllAnimations: { [any]: string } = {}

    for _AnimationName, AnimationId in pairs(AnimationDatabase) do
        table.insert(AllAnimations, AnimationId)
    end

    AnimationService.Preload(Player, AllAnimations)
end

Player.CharacterAdded:Connect(function()
    task.wait(0.1)
    PreloadAllAnimations()
end)

if Player.Character then
    PreloadAllAnimations()
end

Packets.PlayAnimation.OnClientEvent:Connect(function(AnimationId: string, Options: any?)
    AnimationService.Play(Player, AnimationId, Options)
end)

Packets.StopAnimation.OnClientEvent:Connect(function(AnimationId: string, FadeTime: number?)
    if AnimationId and AnimationId ~= "" then
        AnimationService.Stop(Player, AnimationId, FadeTime)
    else
        AnimationService.StopAll(Player, FadeTime)
    end
end)