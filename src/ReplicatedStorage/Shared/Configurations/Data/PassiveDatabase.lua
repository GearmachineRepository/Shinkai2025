--!strict

export type PassiveData = {
    DisplayName: string,
    Description: string,

    Overrides: {
        Animations: { [string]: string }?,
        Sounds: { [string]: string }?,
        Vfx: { [string]: string }?,
    }?,

    Modifiers: {
        [string]: number,
    }?,
}

local PassiveDatabase: { [string]: PassiveData } = {
    Quickstep = {
        DisplayName = "Quickstep",
        Description = "Your dashes are faster and use a different animation.",

        Overrides = {
            Animations = {
                Dash = "rbxassetid://300000",
            },
        },

        Modifiers = {
            DashDuration = 0.7,
            DashCooldown = 0.8,
        },
    },

    Powderwind = {
        DisplayName = "Powderwind",
        Description = "Fire attacks become explosive.",

        Overrides = {
            Vfx = {
                FireSlash = "ExplosionSlash",
                FireHit = "ExplosionHit",
            },
            Sounds = {
                FireSwing = "ExplosionSwing",
            },
        },

        Modifiers = {
            FireHitboxScale = 1.3,
        },
    },

    CombatRecovery = {
        DisplayName = "Combat Recovery",
        Description = "Cooldowns reduced by 25% when out of combat.",

        Modifiers = {
            OutOfCombatCooldownMult = 0.75,
        },
    },
}

local PassiveDatabaseModule = {}

function PassiveDatabaseModule.Get(PassiveId: string): PassiveData?
    return PassiveDatabase[PassiveId]
end

function PassiveDatabaseModule.GetAnimationOverride(PassiveId: string, AnimationType: string): string?
    local Data = PassiveDatabase[PassiveId]
    if not Data or not Data.Overrides or not Data.Overrides.Animations then
        return nil
    end
    return Data.Overrides.Animations[AnimationType]
end

function PassiveDatabaseModule.GetVfxOverride(PassiveId: string, VfxName: string): string?
    local Data = PassiveDatabase[PassiveId]
    if not Data or not Data.Overrides or not Data.Overrides.Vfx then
        return nil
    end
    return Data.Overrides.Vfx[VfxName]
end

function PassiveDatabaseModule.GetSoundOverride(PassiveId: string, SoundName: string): string?
    local Data = PassiveDatabase[PassiveId]
    if not Data or not Data.Overrides or not Data.Overrides.Sounds then
        return nil
    end
    return Data.Overrides.Sounds[SoundName]
end

function PassiveDatabaseModule.GetModifier(PassiveId: string, ModifierName: string): number?
    local Data = PassiveDatabase[PassiveId]
    if not Data or not Data.Modifiers then
        return nil
    end
    return Data.Modifiers[ModifierName]
end

return PassiveDatabaseModule