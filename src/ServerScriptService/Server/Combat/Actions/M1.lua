--!strict
-- Server/Combat/Actions/M1.lua

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.Parent.CombatTypes)
local ActionExecutor = require(script.Parent.Parent.ActionExecutor)
local HitboxManager = require(script.Parent.Parent.Hitbox.HitboxManager)

local WeaponDatabase = require(Shared.Configurations.Data.WeaponDatabase)
local Packets = require(Shared.Networking.Packets)

type ActionContext = CombatTypes.ActionContext

local COMBO_RESET_TIME = 1.5

local ComboStates: { [any]: { Index: number, ResetTime: number } } = {}

local M1 = {}

M1.ActionName = "M1"
M1.ActionType = "Attack"

M1.DefaultMetadata = {
    ActionName = "M1",
    BaseDamage = 10,
    StaminaCost = 5,
    HitboxSize = Vector3.new(4, 4, 4),
    HitboxOffset = CFrame.new(0, 0, -3),

    FallbackTimings = {
        HitStart = 0.15,
        HitEnd = 0.35,
    },
}

local function GetComboIndex(Entity: any): number
    local State = ComboStates[Entity]

    if not State or os.clock() > State.ResetTime then
        ComboStates[Entity] = { Index = 1, ResetTime = os.clock() + COMBO_RESET_TIME }
        return 1
    end

    return State.Index
end

local function AdvanceCombo(Entity: any, WeaponData: any)
    local State = ComboStates[Entity]
    if not State then
        return
    end

    local MaxCombo = WeaponData.Stats.ComboLength or #WeaponData.Animations.LightCombo
    State.Index = (State.Index % MaxCombo) + 1
    State.ResetTime = os.clock() + COMBO_RESET_TIME
end

local function GetEquippedWeapon(Entity: any): string
    local ToolComponent = Entity:GetComponent("Tool")
    if ToolComponent and ToolComponent.EquippedWeapon then
        return ToolComponent.EquippedWeapon
    end
    return "Fists"
end

function M1.CanExecute(Context: ActionContext): (boolean, string?)
    local Entity = Context.Entity

    if Entity.States:GetState("Stunned") then
        return false, "Stunned"
    end

    if Entity.States:GetState("Attacking") then
        return false, "Already attacking"
    end

    local WeaponId = GetEquippedWeapon(Entity)
    local WeaponData = WeaponDatabase.Get(WeaponId)

    local StaminaCost = if WeaponData then WeaponData.Stats.StaminaCost else M1.DefaultMetadata.StaminaCost
    StaminaCost = Entity.Modifiers:Apply("StaminaCost", StaminaCost)

    local Stamina = Entity.Stats:GetStat("Stamina")
    if Stamina < StaminaCost then
        return false, "Not enough stamina"
    end

    return true, nil
end

function M1.OnStart(Context: ActionContext)
    local Entity = Context.Entity

    local WeaponId = GetEquippedWeapon(Entity)
    local WeaponData = WeaponDatabase.Get(WeaponId)
    local ComboIndex = GetComboIndex(Entity)

    Context.CustomData.WeaponId = WeaponId
    Context.CustomData.WeaponData = WeaponData
    Context.CustomData.ComboIndex = ComboIndex

    Entity.States:SetState("Attacking", true)

    local StaminaCost = if WeaponData then WeaponData.Stats.StaminaCost else M1.DefaultMetadata.StaminaCost
    StaminaCost = Entity.Modifiers:Apply("StaminaCost", StaminaCost)
    Entity.Stats:ModifyStat("Stamina", -StaminaCost)

    local AnimationId = WeaponDatabase.GetAnimation(WeaponId, "LightCombo", ComboIndex)
    local SoundName = WeaponDatabase.GetSound(WeaponId, "Swing")

    if Entity.Player then
        Packets.EventFired:Fire(Entity.Character, "ActionStarted", {
            ActionName = "M1",
            AnimationId = AnimationId,
            SoundName = SoundName,
            ComboIndex = ComboIndex,
        })
    end
end

function M1.OnExecute(Context: ActionContext)
    local Entity = Context.Entity
    local WeaponData = Context.CustomData.WeaponData
    local WeaponId = Context.CustomData.WeaponId
    local ComboIndex = Context.CustomData.ComboIndex

    local AnimationId = WeaponDatabase.GetAnimation(WeaponId, "LightCombo", ComboIndex)
    if not AnimationId then return end
    local Timings = ActionExecutor.GetTimings(AnimationId, M1.DefaultMetadata.FallbackTimings)

    local HitStart = Timings.HitStart or 0.15
    local HitEnd = Timings.HitEnd or 0.35
    local Duration = Timings.Duration or 0.5

    task.wait(HitStart)

    if Context.Interrupted then
        return
    end

    local BaseDamage = if WeaponData then WeaponData.Stats.BaseDamage else M1.DefaultMetadata.BaseDamage
    local _Damage = Entity.Modifiers:Apply("Attack", BaseDamage)

    HitboxManager.CreateHitbox({
        Owner = Entity,
        Size = M1.DefaultMetadata.HitboxSize,
        Offset = M1.DefaultMetadata.HitboxOffset,
        Duration = HitEnd - HitStart,
        OnHit = function(Target)
            if Context.Interrupted then
                return
            end
            M1.OnHit(Context, Target)
        end,
    })

    task.wait(Duration - HitStart)
end

function M1.OnHit(Context: ActionContext, Target: any)
    local Entity = Context.Entity
    local WeaponData = Context.CustomData.WeaponData

    local BaseDamage = if WeaponData then WeaponData.Stats.BaseDamage else M1.DefaultMetadata.BaseDamage
    local Damage = Entity.Modifiers:Apply("Attack", BaseDamage)
    Damage = Target.Modifiers:Apply("Damage", Damage)

    Target.Stats:ModifyStat("Health", -Damage)

    Ensemble.Events.Publish("AttackHit", {
        Attacker = Entity,
        Target = Target,
        Damage = Damage,
        ActionName = "M1",
    })

    local HitSound = WeaponDatabase.GetSound(Context.CustomData.WeaponId, "Hit")

    Packets.EventFired:Fire(Target.Character, "Hit", {
        AttackerCharacter = Entity.Character,
        Damage = Damage,
        HitSound = HitSound,
    })
end

function M1.OnComplete(Context: ActionContext)
    local Entity = Context.Entity
    local WeaponData = Context.CustomData.WeaponData

    AdvanceCombo(Entity, WeaponData)
end

function M1.OnCleanup(Context: ActionContext)
    local Entity = Context.Entity

    if Entity.States:GetState("Attacking") then
        Entity.States:SetState("Attacking", false)
    end
end

return M1