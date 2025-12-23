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
    ACTION LIFECYCLE:

    1. CanExecute(Context) -> boolean, string?
       - Return false to prevent action
       - Called before anything happens

    2. OnStart(Context)
       - Action begins, set states, drain resources
       - Replication sent after this

    3. OnExecute(Context)
       - Main action logic, hitboxes, timing
       - Runs in separate thread
       - Check Context.Interrupted during long actions

    4a. OnComplete(Context)
        - Normal completion
        - Called if not interrupted

    4b. OnInterrupt(Context)
        - Called when action is cancelled/feinted
        - Context.InterruptReason contains why

    5. OnCleanup(Context)
       - Always called at the end
       - Clean up any lingering state

    CONTEXT FIELDS:
    - Entity: The acting entity
    - InputData: Data from client input
    - Metadata: Action config (can be modified by hooks)
    - StartTime: When action started
    - Interrupted: Whether action was interrupted
    - InterruptReason: Why it was interrupted
    - CustomData: Store anything during execution
]=]

local ActionTemplate = {}

ActionTemplate.ActionName = "TemplateName"
ActionTemplate.ActionType = "Attack"

ActionTemplate.DefaultMetadata = {
    ActionName = "TemplateName",
    BaseDamage = 10,
    StaminaCost = 5,
    Duration = 0.5,
    Cooldown = 0.5,
    AnimationId = "rbxassetid://0",
    HitboxSize = Vector3.new(4, 4, 4),
    HitboxOffset = CFrame.new(0, 0, -3),

    CanFeint = true,
    FeintWindow = 0.2,

    FallbackTimings = {
        HitStart = 0.15,
        HitEnd = 0.35,
        FeintEnd = 0.2,
    },
}

function ActionTemplate.CanExecute(Context: ActionContext): (boolean, string?)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    if Entity.States:GetState("Stunned") then
        return false, "Stunned"
    end

    if Entity.States:GetState("Attacking") then
        return false, "Already attacking"
    end

    local Stamina = Entity.Stats:GetStat("Stamina")
    local Cost = Entity.Modifiers:Apply("StaminaCost", Metadata.StaminaCost or 0)

    if Stamina < Cost then
        return false, "Not enough stamina"
    end

    return true, nil
end

function ActionTemplate.OnStart(Context: ActionContext)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    Entity.States:SetState("Attacking", true)

    local Cost = Entity.Modifiers:Apply("StaminaCost", Metadata.StaminaCost or 0)
    Entity.Stats:ModifyStat("Stamina", -Cost)

    CombatController.Replicate("ActionStarted", Entity, {
        ActionName = Metadata.ActionName,
        AnimationId = Metadata.AnimationId,
        Duration = Metadata.Duration,
    })
end

function ActionTemplate.OnExecute(Context: ActionContext)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    local Timings = ActionExecutor.GetTimings(Metadata.AnimationId, Metadata.FallbackTimings)

    local HitStart = Timings.HitStart or 0.15
    local HitEnd = Timings.HitEnd or 0.35
    local HitDuration = HitEnd - HitStart

    task.wait(HitStart)

    if Context.Interrupted then
        return
    end

    local CancelHitbox = HitboxManager.CreateHitbox({
        Owner = Entity,
        Size = Metadata.HitboxSize,
        Offset = Metadata.HitboxOffset,
        Duration = HitDuration,
        OnHit = function(Target)
            if Context.Interrupted then
                return
            end
            ActionTemplate.OnHit(Context, Target, 1)
        end,
    })

    Context.CustomData.CancelHitbox = CancelHitbox

    local Remaining = (Metadata.Duration or 0.5) - HitStart
    task.wait(Remaining)
end

function ActionTemplate.OnHit(Context: ActionContext, Target: any, HitIndex: number)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    local BaseDamage = Metadata.BaseDamage or 10
    local Damage = Entity.Modifiers:Apply("Attack", BaseDamage)
    Damage = Target.Modifiers:Apply("Damage", Damage)

    Target.Stats:ModifyStat("Health", -Damage)

    Ensemble.Events.Publish("AttackHit", {
        Attacker = Entity,
        Target = Target,
        Damage = Damage,
        HitIndex = HitIndex,
        ActionName = Metadata.ActionName,
    })

    CombatController.Replicate("Hit", Target, {
        AttackerCharacter = Entity.Character,
        Damage = Damage,
    })
end

function ActionTemplate.OnInterrupt(Context: ActionContext)
    local Entity = Context.Entity
    local Reason = Context.InterruptReason

    if Context.CustomData.CancelHitbox then
        Context.CustomData.CancelHitbox()
    end

    CombatController.Replicate("ActionInterrupted", Entity, {
        ActionName = Context.Metadata.ActionName,
        Reason = Reason,
    })
end

function ActionTemplate.OnComplete(Context: ActionContext)
    local Entity = Context.Entity
    local Metadata = Context.Metadata

    if Metadata.Cooldown and Metadata.Cooldown > 0 then
        -- Start cooldown via your cooldown system
    end

    CombatController.Replicate("ActionCompleted", Entity, {
        ActionName = Metadata.ActionName,
    })
end

function ActionTemplate.OnCleanup(Context: ActionContext)
    local Entity = Context.Entity

    if Entity.States:GetState("Attacking") then
        Entity.States:SetState("Attacking", false)
    end

    if Context.CustomData.CancelHitbox then
        Context.CustomData.CancelHitbox()
    end
end

return ActionTemplate