--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local CombatValidationConfig = require(Shared.Configurations.CombatValidationConfig)

export type AfroDashMetadata = {
        ComboIndex: number?,
        ComboLength: number?,
}

local AfroDash = {}

local Windows: { [any]: { ActionName: string, Metadata: AfroDashMetadata?, Expires: number } } = {}

local function getConfig()
        return CombatBalance.AfroDash or {
                InputWindowSeconds = 0.2,
                DashActionName = "Dodge",
                AllowFutureInputs = true,
        }
end

local function isFinalCombo(metadata: AfroDashMetadata?): boolean
        if not metadata then
                return false
        end
        if not metadata.ComboIndex or not metadata.ComboLength then
                return false
        end
        return metadata.ComboIndex >= metadata.ComboLength
end

local function getIgnoredStates(ActionName: string): { [string]: boolean }?
        local Definition = CombatValidationConfig.Actions[ActionName]
        if not Definition or not Definition.AfroDashIgnoredStates then
                return nil
        end

        local Result: { [string]: boolean } = {}
        for _, StateName in Definition.AfroDashIgnoredStates do
                Result[StateName] = true
        end
        return Result
end

local function qualifiesForAfroDash(ActionName: string, Metadata: AfroDashMetadata?, Config: any): boolean
        if ActionName == "LightAttack" or ActionName == "M1" then
                return isFinalCombo(Metadata)
        end

        if ActionName == "HeavyAttack" or ActionName == "M2" then
                return true
        end

        return Config.AllowFutureInputs == true
end

local function isValidCombo(FirstAction: string, SecondAction: string, FirstMetadata: AfroDashMetadata?, SecondMetadata: AfroDashMetadata?)
        local Config = getConfig()
        local DashName = Config.DashActionName or "Dodge"

        if FirstAction == DashName and SecondAction ~= DashName then
                return qualifiesForAfroDash(SecondAction, SecondMetadata, Config)
        end

        if SecondAction == DashName and FirstAction ~= DashName then
                return qualifiesForAfroDash(FirstAction, FirstMetadata, Config)
        end

        return false
end

function AfroDash.ClearWindow(Actor: any)
        Windows[Actor] = nil
end

function AfroDash.ShouldAllowConcurrent(Actor: any, ActionName: string, Metadata: AfroDashMetadata?): (boolean, { [string]: boolean }?)
        local Now = os.clock()
        local Existing = Windows[Actor]

        if Existing and Existing.Expires >= Now then
                if isValidCombo(Existing.ActionName, ActionName, Existing.Metadata, Metadata) then
                        Windows[Actor] = nil
                        return true, getIgnoredStates(ActionName)
                end
        end

        local Config = getConfig()
        Windows[Actor] = {
                ActionName = ActionName,
                Metadata = Metadata,
                Expires = Now + (Config.InputWindowSeconds or 0),
        }

        return false, nil
end

return AfroDash
