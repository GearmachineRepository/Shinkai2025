--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponDatabase = require(Shared.Configurations.Data.WeaponDatabase)
local StyleDatabase = require(Shared.Configurations.Data.StyleDatabase)
local PassiveDatabase = require(Shared.Configurations.Data.PassiveDatabase)

local CombatContext = require(script.Parent.CombatContext)

export type PredictionData = {
    AnimationId: string?,
    AnimationSpeed: number,
    SoundName: string?,
    VfxName: string?,
    CanPredict: boolean,
    CustomData: { [string]: any }?,
}

local PredictionResolver = {}

local function ResolveWithPassiveOverrides(BaseValue: string?, OverrideType: string, Key: string): string?
    if not BaseValue then
        return nil
    end

    local ActivePassives = CombatContext.Get("ActivePassives")

    for PassiveName in ActivePassives do
        local Override: string?

        if OverrideType == "Animation" then
            Override = PassiveDatabase.GetAnimationOverride(PassiveName, Key)
        elseif OverrideType == "Vfx" then
            Override = PassiveDatabase.GetVfxOverride(PassiveName, Key)
        elseif OverrideType == "Sound" then
            Override = PassiveDatabase.GetSoundOverride(PassiveName, Key)
        end

        if Override then
            return Override
        end
    end

    return BaseValue
end

function PredictionResolver.Resolve(ActionName: string): PredictionData
    local Default: PredictionData = {
        AnimationId = nil,
        AnimationSpeed = 1,
        SoundName = nil,
        VfxName = nil,
        CanPredict = false,
    }

    if ActionName == "M1" then
        return PredictionResolver.ResolveLightAttack()
    elseif ActionName == "M2" then
        return PredictionResolver.ResolveHeavyAttack()
    elseif ActionName == "Block" then
        return PredictionResolver.ResolveBlock()
    elseif ActionName == "Dash" then
        return PredictionResolver.ResolveDash()
    end

    return Default
end

function PredictionResolver.ResolveLightAttack(): PredictionData
    local WeaponId = CombatContext.Get("EquippedWeapon") or "Fists"
    local ComboIndex = CombatContext.GetComboIndex() + 1

    local AnimationId = WeaponDatabase.GetAnimation(WeaponId, "LightCombo", ComboIndex)
    local SoundName = WeaponDatabase.GetSound(WeaponId, "Swing")

    AnimationId = ResolveWithPassiveOverrides(AnimationId, "Animation", "LightAttack")
    SoundName = ResolveWithPassiveOverrides(SoundName, "Sound", "Swing")

    return {
        AnimationId = AnimationId,
        AnimationSpeed = 1,
        SoundName = SoundName,
        VfxName = nil,
        CanPredict = true,
        CustomData = {
            ComboIndex = ComboIndex,
        },
    }
end

function PredictionResolver.ResolveHeavyAttack(): PredictionData
    local WeaponId = CombatContext.Get("EquippedWeapon") or "Fists"

    local AnimationId = WeaponDatabase.GetAnimation(WeaponId, "HeavyAttack", nil)
    local SoundName = WeaponDatabase.GetSound(WeaponId, "HeavySwing")

    AnimationId = ResolveWithPassiveOverrides(AnimationId, "Animation", "HeavyAttack")

    return {
        AnimationId = AnimationId,
        AnimationSpeed = 1,
        SoundName = SoundName,
        VfxName = nil,
        CanPredict = true,
    }
end

function PredictionResolver.ResolveBlock(): PredictionData
    local WeaponId = CombatContext.Get("EquippedWeapon") or "Fists"

    local AnimationId = WeaponDatabase.GetAnimation(WeaponId, "Block", nil)

    return {
        AnimationId = AnimationId,
        AnimationSpeed = 1,
        SoundName = nil,
        VfxName = nil,
        CanPredict = true,
    }
end

function PredictionResolver.ResolveDash(): PredictionData
    local StyleId = CombatContext.Get("EquippedStyle") or "Default"

    local AnimationId = StyleDatabase.GetAnimation(StyleId, "Dash")

    AnimationId = ResolveWithPassiveOverrides(AnimationId, "Animation", "Dash")

    local DashDuration = 0.3
    local ActivePassives = CombatContext.Get("ActivePassives")

    for PassiveName in ActivePassives do
        local DurationMult = PassiveDatabase.GetModifier(PassiveName, "DashDuration")
        if DurationMult then
            DashDuration = DashDuration * DurationMult
        end
    end

    return {
        AnimationId = AnimationId,
        AnimationSpeed = 1,
        SoundName = "Dodge",
        VfxName = "DodgeVfx",
        CanPredict = true,
        CustomData = {
            DashDuration = DashDuration,
        },
    }
end

function PredictionResolver.ResolveVfx(BaseVfxName: string): string
    return ResolveWithPassiveOverrides(BaseVfxName, "Vfx", BaseVfxName) or BaseVfxName
end

function PredictionResolver.ResolveSound(BaseSoundName: string): string
    return ResolveWithPassiveOverrides(BaseSoundName, "Sound", BaseSoundName) or BaseSoundName
end

return PredictionResolver