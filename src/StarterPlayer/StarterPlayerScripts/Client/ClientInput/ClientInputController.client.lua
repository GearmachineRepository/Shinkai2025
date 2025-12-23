--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Client = script.Parent.Parent

local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)
local AnimationService = require(Shared.Services.AnimationService)
local SoundPlayer = require(Shared.General.SoundPlayer)
local VfxPlayer = require(Shared.VFX.VfxPlayer)

local CombatContext = require(Client.Combat.CombatContext)
local PredictionResolver = require(Client.Combat.PredictionResolver)
local DashPrediction = require(Client.Combat.Predictions.DashPrediction)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

type PredictionModule = {
    CanExecute: ((PredictionData: any) -> boolean)?,
    Execute: (PredictionData: any) -> boolean,
    Rollback: () -> (),
}

local CustomPredictions: { [string]: PredictionModule } = {
    Dash = DashPrediction,
}

local PendingActions: { [string]: boolean } = {}

CombatContext.Initialize()

local function PlayDefaultPrediction(_ActionName: string, PredictionData: any)
    local Character = LocalPlayer.Character
    if not Character then
        return
    end

    if PredictionData.AnimationId then
        AnimationService.Play(LocalPlayer, PredictionData.AnimationId, {
            Priority = Enum.AnimationPriority.Action,
            Speed = PredictionData.AnimationSpeed,
        })
    end

    if PredictionData.SoundName then
        local ResolvedSound = PredictionResolver.ResolveSound(PredictionData.SoundName)
        SoundPlayer.Play(Character, ResolvedSound)
    end

    if PredictionData.VfxName then
        local ResolvedVfx = PredictionResolver.ResolveVfx(PredictionData.VfxName)
        VfxPlayer.Play(Character, ResolvedVfx)
    end
end

local function CancelPrediction()
    AnimationService.StopAll(LocalPlayer, 0.1)

    local Character = LocalPlayer.Character
    if Character then
        VfxPlayer.CleanupAll(Character)
    end
end

InputBuffer.OnAction(function(ActionName: string)
    local PredictionData = PredictionResolver.Resolve(ActionName)

    if not PredictionData.CanPredict then
        Packets.PerformAction:Fire(ActionName)
        return
    end

    local CustomPrediction = CustomPredictions[ActionName]

    if CustomPrediction then
        local CanExecute = true
        if CustomPrediction.CanExecute then
            CanExecute = CustomPrediction.CanExecute(PredictionData)
        end

        if CanExecute then
            CustomPrediction.Execute(PredictionData)
            PendingActions[ActionName] = true
        else
            return
        end
    else
        PlayDefaultPrediction(ActionName, PredictionData)
        PendingActions[ActionName] = true
    end

    Packets.PerformAction:Fire(ActionName)
end)

Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
    PendingActions[ActionName] = nil
end)

Packets.ActionDenied.OnClientEvent:Connect(function(_Reason: string)
    for ActionName in PendingActions do
        local CustomPrediction = CustomPredictions[ActionName]
        if CustomPrediction then
            CustomPrediction.Rollback()
        end
    end

    table.clear(PendingActions)
    CancelPrediction()
    CombatContext.ResetCombo()
end)