--!strict
-- Client/Combat/Predictions/DashPrediction.lua

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationService = require(Shared.Services.AnimationService)
local SoundPlayer = require(Shared.General.SoundPlayer)
local VfxPlayer = require(Shared.VFX.VfxPlayer)

local Client = Players.LocalPlayer.PlayerScripts:WaitForChild("Client")
local PredictionResolver = require(Client.Combat.PredictionResolver)

local LocalPlayer = Players.LocalPlayer

local DashPrediction = {}

local BASE_DASH_DISTANCE = 15
local BASE_DASH_DURATION = 0.3

local IsDashing = false
local DashConnection: RBXScriptConnection? = nil
local _CurrentPredictionData: any? = nil

function DashPrediction.CanExecute(_PredictionData: any): boolean
    if IsDashing then
        return false
    end

    local Character = LocalPlayer.Character
    if not Character then
        return false
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then
        return false
    end

    return true
end

function DashPrediction.Execute(PredictionData: any): boolean
    local Character = LocalPlayer.Character
    if not Character then
        return false
    end

    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")

    if not HumanoidRootPart or not Humanoid then
        return false
    end

    IsDashing = true
    _CurrentPredictionData = PredictionData

    local DashDuration = BASE_DASH_DURATION
    if PredictionData.CustomData and PredictionData.CustomData.DashDuration then
        DashDuration = PredictionData.CustomData.DashDuration
    end

    local DashDirection = Humanoid.MoveDirection
    if DashDirection.Magnitude < 0.1 then
        DashDirection = HumanoidRootPart.CFrame.LookVector
    end
    DashDirection = DashDirection.Unit

    if PredictionData.AnimationId then
        AnimationService.Play(LocalPlayer, PredictionData.AnimationId, {
            Priority = Enum.AnimationPriority.Action,
        })
    end

    if PredictionData.VfxName then
        local ResolvedVfx = PredictionResolver.ResolveVfx(PredictionData.VfxName)
        VfxPlayer.Play(Character, ResolvedVfx)
    end

    if PredictionData.SoundName then
        local ResolvedSound = PredictionResolver.ResolveSound(PredictionData.SoundName)
        SoundPlayer.Play(Character, ResolvedSound)
    end

    local StartPosition = HumanoidRootPart.Position
    local TargetPosition = StartPosition + (DashDirection * BASE_DASH_DISTANCE)
    local Elapsed = 0

    local _OriginalAutoRotate = Humanoid.AutoRotate
    Humanoid.AutoRotate = false

    DashConnection = RunService.Heartbeat:Connect(function(DeltaTime)
        Elapsed += DeltaTime
        local Alpha = math.min(Elapsed / DashDuration, 1)

        local EasedAlpha = 1 - math.pow(1 - Alpha, 3)

        local NewPosition = StartPosition:Lerp(TargetPosition, EasedAlpha)
        HumanoidRootPart.CFrame = CFrame.new(NewPosition) * CFrame.Angles(0, math.atan2(-DashDirection.X, -DashDirection.Z), 0)

        if Alpha >= 1 then
            DashPrediction.Complete()
        end
    end)

    return true
end

function DashPrediction.Complete()
    if DashConnection then
        DashConnection:Disconnect()
        DashConnection = nil
    end

    IsDashing = false

    local Character = LocalPlayer.Character
    if Character then
        local Humanoid = Character:FindFirstChildOfClass("Humanoid")
        if Humanoid then
            Humanoid.AutoRotate = true
        end
    end

    _CurrentPredictionData = nil
end

function DashPrediction.Rollback()
    DashPrediction.Complete()

    local Character = LocalPlayer.Character
    if Character then
        VfxPlayer.Cleanup(Character, "DodgeVfx", true)
        AnimationService.StopAll(LocalPlayer, 0.05)
    end
end

function DashPrediction.IsDashing(): boolean
    return IsDashing
end

return DashPrediction