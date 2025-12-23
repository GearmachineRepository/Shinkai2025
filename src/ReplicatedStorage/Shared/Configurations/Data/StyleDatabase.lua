--!strict

export type StyleData = {
    DisplayName: string,

    Animations: {
        Dash: string,
        Idle: string?,
        Run: string?,
    },

    Modifiers: {
        DashDistance: number?,
        DashDuration: number?,
        StaminaRegenMult: number?,
    }?,
}

local StyleDatabase: { [string]: StyleData } = {
    Default = {
        DisplayName = "Default",
        Animations = {
            Dash = "rbxassetid://200000",
        },
    },

    Assassin = {
        DisplayName = "Assassin",
        Animations = {
            Dash = "rbxassetid://210000",
            Idle = "rbxassetid://210001",
            Run = "rbxassetid://210002",
        },
        Modifiers = {
            DashDistance = 1.2,
        },
    },

    Berserker = {
        DisplayName = "Berserker",
        Animations = {
            Dash = "rbxassetid://220000",
        },
        Modifiers = {
            StaminaRegenMult = 0.8,
        },
    },
}

local StyleDatabaseModule = {}

function StyleDatabaseModule.Get(StyleId: string): StyleData?
    return StyleDatabase[StyleId]
end

function StyleDatabaseModule.GetAnimation(StyleId: string, AnimationType: string): string?
    local Data = StyleDatabase[StyleId] or StyleDatabase.Default
    return Data.Animations[AnimationType]
end

function StyleDatabaseModule.GetModifier(StyleId: string, ModifierName: string): number?
    local Data = StyleDatabase[StyleId]
    if not Data or not Data.Modifiers then
        return nil
    end
    return Data.Modifiers[ModifierName]
end

return StyleDatabaseModule