--!strict

export type WeaponData = {
    DisplayName: string,
    Category: string,

    Animations: {
        LightCombo: { string },
        HeavyAttack: string?,
        Block: string?,
        Parry: string?,
    },

    Sounds: {
        Swing: string?,
        HeavySwing: string?,
        Hit: string?,
    },

    Stats: {
        BaseDamage: number,
        StaminaCost: number,
        ComboLength: number,
    },
}

local WeaponDatabase: { [string]: WeaponData } = {
    Katana = {
        DisplayName = "Katana",
        Category = "Sword",

        Animations = {
            LightCombo = {
                "rbxassetid://111111",
                "rbxassetid://222222",
                "rbxassetid://333333",
                "rbxassetid://444444",
            },
            HeavyAttack = "rbxassetid://555555",
            Block = "rbxassetid://666666",
            Parry = "rbxassetid://777777",
        },

        Sounds = {
            Swing = "KatanaSwing",
            HeavySwing = "KatanaHeavy",
            Hit = "KatanaHit",
        },

        Stats = {
            BaseDamage = 10,
            StaminaCost = 5,
            ComboLength = 4,
        },
    },

    Greatsword = {
        DisplayName = "Greatsword",
        Category = "Heavy",

        Animations = {
            LightCombo = {
                "rbxassetid://120810578835776",
                "rbxassetid://135298421079091",
                "rbxassetid://90246825026625",
                "rbxassetid://71745443772185",
            },
            HeavyAttack = "rbxassetid://111111",
            Block = "rbxassetid://121212",
        },

        Sounds = {
            Swing = "GreatswordSwing",
            Hit = "GreatswordHit",
        },

        Stats = {
            BaseDamage = 18,
            StaminaCost = 8,
            ComboLength = 3,
        },
    },

    Fists = {
        DisplayName = "Fists",
        Category = "Unarmed",

        Animations = {
            LightCombo = {
                "rbxassetid://120810578835776",
                "rbxassetid://135298421079091",
                "rbxassetid://90246825026625",
                "rbxassetid://71745443772185",
            },
            HeavyAttack = "rbxassetid://181818",
            Block = "rbxassetid://191919",
        },

        Sounds = {
            Swing = "FistSwing",
            Hit = "FistHit",
        },

        Stats = {
            BaseDamage = 6,
            StaminaCost = 3,
            ComboLength = 5,
        },
    },
}

local WeaponDatabaseModule = {}

function WeaponDatabaseModule.Get(WeaponId: string): WeaponData?
    return WeaponDatabase[WeaponId]
end

function WeaponDatabaseModule.GetAnimation(WeaponId: string, AnimationType: string, ComboIndex: number?): string?
    local Data = WeaponDatabase[WeaponId]
    if not Data then
        return nil
    end

    local Animations = Data.Animations

    if AnimationType == "LightCombo" and ComboIndex then
        local Combo = Animations.LightCombo
        local Index = ((ComboIndex - 1) % #Combo) + 1
        return Combo[Index]
    end

    return Animations[AnimationType]
end

function WeaponDatabaseModule.GetSound(WeaponId: string, SoundType: string): string?
    local Data = WeaponDatabase[WeaponId]
    if not Data then
        return nil
    end
    return Data.Sounds[SoundType]
end

function WeaponDatabaseModule.GetStat(WeaponId: string, StatName: string): number?
    local Data = WeaponDatabase[WeaponId]
    if not Data then
        return nil
    end
    return Data.Stats[StatName]
end

return WeaponDatabaseModule