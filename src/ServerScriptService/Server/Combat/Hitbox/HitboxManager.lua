--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)

type HitboxConfig = {
    Owner: any,
    Size: Vector3,
    Offset: CFrame,
    Duration: number,
    OnHit: (Target: any) -> (),
    MaxTargets: number?,
    IgnoreList: { Model }?,
    Shape: ("Box" | "Sphere")?,
    FollowOwner: boolean?,
}

type ActiveHitbox = {
    Config: HitboxConfig,
    StartTime: number,
    HitTargets: { [Model]: boolean },
    HitCount: number,
    Cancelled: boolean,
}

local HitboxManager = {}

local ActiveHitboxes: { ActiveHitbox } = {}
local OverlapParams = OverlapParams.new()
OverlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function GetHitboxCFrame(Hitbox: ActiveHitbox): CFrame
    local Owner = Hitbox.Config.Owner
    local Character = Owner.Character

    if not Character then
        return CFrame.new()
    end

    local RootPart = Character:FindFirstChild("HumanoidRootPart")
    if not RootPart then
        return CFrame.new()
    end

    if Hitbox.Config.FollowOwner ~= false then
        return RootPart.CFrame * Hitbox.Config.Offset
    else
        return Hitbox.Config.Offset
    end
end

local function CheckHitbox(Hitbox: ActiveHitbox)
    if Hitbox.Cancelled then
        return
    end

    local Config = Hitbox.Config
    local MaxTargets = Config.MaxTargets or 10

    if Hitbox.HitCount >= MaxTargets then
        return
    end

    local HitboxCFrame = GetHitboxCFrame(Hitbox)
    local Size = Config.Size

    local IgnoreList = { Config.Owner.Character }
    if Config.IgnoreList then
        for _, Model in Config.IgnoreList do
            table.insert(IgnoreList, Model)
        end
    end

    OverlapParams.FilterDescendantsInstances = IgnoreList

    local Parts: { BasePart }
    if Config.Shape == "Sphere" then
        Parts = workspace:GetPartBoundsInRadius(HitboxCFrame.Position, Size.X / 2, OverlapParams)
    else
        Parts = workspace:GetPartBoundsInBox(HitboxCFrame, Size, OverlapParams)
    end

    for _, Part in Parts do
        if Hitbox.HitCount >= MaxTargets then
            break
        end

        local Character = Part.Parent :: Model?
        if not Character then
            continue
        end

        local Humanoid = Character:FindFirstChildOfClass("Humanoid") :: Humanoid?
        if not Humanoid then
             continue
        end

        if not Humanoid or Humanoid.Health <= 0 then
            continue
        end

        if Hitbox.HitTargets[Character] then
            continue
        end

        local TargetEntity = Ensemble.GetEntity(Character)
        if not TargetEntity then
            continue
        end

        Hitbox.HitTargets[Character] = true
        Hitbox.HitCount += 1

        task.spawn(Config.OnHit, TargetEntity)
    end
end

function HitboxManager.CreateHitbox(Config: HitboxConfig): () -> ()
    local Hitbox: ActiveHitbox = {
        Config = Config,
        StartTime = workspace:GetServerTimeNow(),
        HitTargets = {},
        HitCount = 0,
        Cancelled = false,
    }

    table.insert(ActiveHitboxes, Hitbox)

    local function Cancel()
        Hitbox.Cancelled = true
    end

    task.spawn(function()
        local Elapsed = 0
        local CheckInterval = 1 / 30

        while Elapsed < Config.Duration and not Hitbox.Cancelled do
            CheckHitbox(Hitbox)
            task.wait(CheckInterval)
            Elapsed += CheckInterval
        end

        local Index = table.find(ActiveHitboxes, Hitbox)
        if Index then
            table.remove(ActiveHitboxes, Index)
        end
    end)

    return Cancel
end

function HitboxManager.CreateInstantHitbox(Config: HitboxConfig): { any }
    local Hitbox: ActiveHitbox = {
        Config = Config,
        StartTime = workspace:GetServerTimeNow(),
        HitTargets = {},
        HitCount = 0,
        Cancelled = false,
    }

    CheckHitbox(Hitbox)

    local Targets = {}
    for Character in Hitbox.HitTargets do
        local Entity = Ensemble.GetEntity(Character)
        if Entity then
            table.insert(Targets, Entity)
        end
    end

    return Targets
end

function HitboxManager.CancelAllForOwner(Owner: any)
    for _, Hitbox in ActiveHitboxes do
        if Hitbox.Config.Owner == Owner then
            Hitbox.Cancelled = true
        end
    end
end

return HitboxManager