--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatController = require(script.Parent.Parent.CombatController)
local ActionExecutor = require(script.Parent.Parent.ActionExecutor)
local HitboxManager = require(script.Parent.Parent.Hitbox.HitboxManager)
local CombatTypes = require(script.Parent.Parent.CombatTypes)

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

type ActionContext = CombatTypes.ActionContext

--[=[
    SKILL EDITS:

    Metadata.SkillEdits comes from inventory and can contain:
    - Range: Modifier to hitbox size/range
    - Speed: Modifier to animation speed
    - Cooldown: Modifier to cooldown time
    - Power: Modifier to damage

    Apply these in OnExecute/OnHit as needed.

    Example from Mighty Omega:
    - Base Power: 75.93, with edits can increase/decrease
    - Speed affects animation playback and timing windows
    - Range affects hitbox size
]=]

local AbilityTemplate = {}

AbilityTemplate.ActionName = "AbilityTemplate"
AbilityTemplate.ActionType = "Ability"

AbilityTemplate.DefaultMetadata = {
    ActionName = "AbilityTemplate",
    BaseDamage = 25,
    StaminaCost = 15,
    Duration = 1.0,
    Cooldown = 5.0,
    AnimationId = "rbxassetid://0",

    BaseRange = 6,
    BaseHitboxSize = Vector3.new(6, 4, 6),
    HitboxOffset = CFrame.new(0, 0, -4),

    CanFeint = true,
    FeintWindow = 0.3,

    WaveCount = 1,
    WaveDelay = 0.2,

    FallbackTimings = {
        HitStart = 0.3,
        HitEnd = 0.8,
    },
}

local function ApplySkillEdits(Metadata: any): any
    local Edits = Metadata.SkillEdits
    if not Edits then
        return Metadata
    end

    local Modified = table.clone(Metadata)

    if Edits.Power then
        local PowerMult = Edits.Power
        Modified.BaseDamage = Modified.BaseDamage * PowerMult
    end

    if Edits.Range then
        local RangeMult = Edits.Range
        local BaseSize = Modified.BaseHitboxSize
        Modified.HitboxSize = Vector3.new(
            BaseSize.X * RangeMult,
            BaseSize.Y,
            BaseSize.Z * RangeMult
        )
    else
        Modified.HitboxSize = Modified.BaseHitboxSize
    end

    if Edits.Speed then
        local SpeedMult = Edits.Speed
        Modified.Duration = Modified.Duration / SpeedMult
        Modified.AnimationSpeed = SpeedMult
    end

    if Edits.Cooldown then
        local CooldownMult = Edits.Cooldown
        Modified.Cooldown = Modified.Cooldown * CooldownMult
    end

    return Modified
end

function AbilityTemplate.CanExecute(Context: ActionContext): (boolean, string?)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    if Entity.States:GetState("Stunned") then
        return false, "Stunned"
    end

    if Entity.States:GetState("Attacking") then
        return false, "Already attacking"
    end

    -- Check cooldown via your cooldown system
    -- if OnCooldown(Entity, Metadata.ActionName) then
    --     return false, "On cooldown"
    -- end

    local Stamina = Entity.Stats:GetStat("Stamina")
    local Cost = Entity.Modifiers:Apply("StaminaCost", Metadata.StaminaCost or 0)

    if Stamina < Cost then
        return false, "Not enough stamina"
    end

    return true, nil
end

function AbilityTemplate.OnStart(Context: ActionContext)
    local Entity = Context.Entity

    local EditedMetadata = ApplySkillEdits(Context.Metadata)
    Context.Metadata = EditedMetadata
    Context.Metadata = Entity.Modifiers:Apply("ActionConfig:" .. EditedMetadata.ActionName, EditedMetadata)

    Entity.States:SetState("Attacking", true)

    local Cost = Entity.Modifiers:Apply("StaminaCost", Context.Metadata.StaminaCost or 0)
    Entity.Stats:ModifyStat("Stamina", -Cost)

    CombatController.Replicate("ActionStarted", Entity, {
        ActionName = Context.Metadata.ActionName,
        AnimationId = Context.Metadata.AnimationId,
        AnimationSpeed = Context.Metadata.AnimationSpeed or 1,
        Duration = Context.Metadata.Duration,
        WaveCount = Context.Metadata.WaveCount,
    })
end

function AbilityTemplate.OnExecute(Context: ActionContext)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    local Timings = ActionExecutor.GetTimings(Metadata.AnimationId, Metadata.FallbackTimings)
    local HitStart = Timings.HitStart or 0.3

    task.wait(HitStart)

    if Context.Interrupted then
        return
    end

    local WaveCount = Metadata.WaveCount or 1
    WaveCount = Entity.Modifiers:Apply("AbilityWaveCount:" .. Metadata.ActionName, WaveCount)

    for Wave = 1, WaveCount do
        if Context.Interrupted then
            return
        end

        local Targets = HitboxManager.CreateInstantHitbox({
            Owner = Entity,
            Size = Metadata.HitboxSize,
            Offset = Metadata.HitboxOffset,
            Duration = 0,
            OnHit = function() end,
        })

        for _, Target in Targets do
            AbilityTemplate.OnHit(Context, Target, Wave)
        end

        CombatController.Replicate("AbilityWave", Entity, {
            ActionName = Metadata.ActionName,
            WaveIndex = Wave,
        })

        if Wave < WaveCount then
            task.wait(Metadata.WaveDelay or 0.2)
        end
    end

    local Remaining = Metadata.Duration - HitStart - ((WaveCount - 1) * (Metadata.WaveDelay or 0.2))
    if Remaining > 0 then
        task.wait(Remaining)
    end
end

function AbilityTemplate.OnHit(Context: ActionContext, Target: any, WaveIndex: number)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    local BaseDamage = Metadata.BaseDamage or 25
    local Damage = Entity.Modifiers:Apply("Attack", BaseDamage)
    Damage = Target.Modifiers:Apply("Damage", Damage)

    Target.Stats:ModifyStat("Health", -Damage)

    Ensemble.Events.Publish("AbilityHit", {
        Attacker = Entity,
        Target = Target,
        Damage = Damage,
        WaveIndex = WaveIndex,
        ActionName = Metadata.ActionName,
    })

    CombatController.Replicate("Hit", Target, {
        AttackerCharacter = Entity.Character,
        Damage = Damage,
        IsAbility = true,
    })
end

function AbilityTemplate.OnInterrupt(Context: ActionContext)
    local Entity = Context.Entity

    CombatController.Replicate("ActionInterrupted", Entity, {
        ActionName = Context.Metadata.ActionName,
        Reason = Context.InterruptReason,
    })
end

function AbilityTemplate.OnComplete(Context: ActionContext)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    -- Start cooldown
    -- StartCooldown(Entity, Metadata.ActionName, Metadata.Cooldown)

    CombatController.Replicate("ActionCompleted", Entity, {
        ActionName = Metadata.ActionName,
    })
end

function AbilityTemplate.OnCleanup(Context: ActionContext)
    local Entity = Context.Entity

    if Entity.States:GetState("Attacking") then
        Entity.States:SetState("Attacking", false)
    end
end

return AbilityTemplate