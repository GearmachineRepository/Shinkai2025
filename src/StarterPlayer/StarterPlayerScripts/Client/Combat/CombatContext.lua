--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local CombatContext = {}

local State = {
    EquippedWeapon = nil :: string?,
    EquippedStyle = nil :: string?,
    ComboIndex = 0,
    ComboResetTime = 0,
    ActivePassives = {} :: { [string]: boolean },
    ActiveHooks = {} :: { [string]: boolean },
    InCombat = false,
}

local COMBO_RESET_WINDOW = 1.5

function CombatContext.Get(Key: string): any
    return State[Key]
end

function CombatContext.GetAll(): typeof(State)
    return table.clone(State)
end

function CombatContext.SetWeapon(WeaponId: string?)
    State.EquippedWeapon = WeaponId
    State.ComboIndex = 0
end

function CombatContext.SetStyle(StyleId: string?)
    State.EquippedStyle = StyleId
end

function CombatContext.SetPassive(PassiveName: string, Active: boolean)
    State.ActivePassives[PassiveName] = if Active then true else false
end

function CombatContext.HasPassive(PassiveName: string): boolean
    return State.ActivePassives[PassiveName] == true
end

function CombatContext.AdvanceCombo()
    State.ComboIndex += 1
    State.ComboResetTime = os.clock() + COMBO_RESET_WINDOW
end

function CombatContext.GetComboIndex(): number
    if os.clock() > State.ComboResetTime then
        State.ComboIndex = 0
    end
    return State.ComboIndex
end

function CombatContext.ResetCombo()
    State.ComboIndex = 0
end

function CombatContext.SetInCombat(InCombat: boolean)
    State.InCombat = InCombat
end

function CombatContext.Initialize()
    Packets.TogglePassive.OnClientEvent:Connect(function(PassiveName: string, Active: boolean)
        CombatContext.SetPassive(PassiveName, Active)
    end)

    Packets.EquipItem.OnClientEvent:Connect(function(SlotIndex: number, ItemId: string)
        if SlotIndex == 1 then
            CombatContext.SetWeapon(ItemId)
        end
    end)

    Packets.StateChanged.OnClientEvent:Connect(function(Character, StateName, Value)
        if Character ~= Players.LocalPlayer.Character then
            return
        end
        if StateName == "InCombat" then
            CombatContext.SetInCombat(Value)
        end
    end)

    Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
        if ActionName == "M1" then
            CombatContext.AdvanceCombo()
        end
    end)

    Packets.ActionDenied.OnClientEvent:Connect(function()
        CombatContext.ResetCombo()
    end)
end

return CombatContext