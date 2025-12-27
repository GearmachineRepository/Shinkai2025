--!strict

local CombatTypes = require(script.Parent.CombatTypes)

type ActionDefinition = CombatTypes.ActionDefinition
type ActionMetadata = CombatTypes.ActionMetadata

local ActionRegistry = {}

local RegisteredActions: { [string]: ActionDefinition } = {}

function ActionRegistry.Register(Definition: ActionDefinition)
    if RegisteredActions[Definition.ActionName] then
        warn("[ActionRegistry] Action already registered: " .. Definition.ActionName)
        return
    end

    RegisteredActions[Definition.ActionName] = Definition
end

function ActionRegistry.Get(ActionName: string): ActionDefinition?
    return RegisteredActions[ActionName]
end

function ActionRegistry.GetWithMetadata(ActionName: string, InventoryMetadata: ActionMetadata?): (ActionDefinition?, ActionMetadata)
    local Definition = RegisteredActions[ActionName]
    if not Definition then
        return nil, {} :: any
    end

    local FinalMetadata = table.clone(Definition.DefaultMetadata)

    if InventoryMetadata then
        for Key, Value in InventoryMetadata do
            FinalMetadata[Key] = Value
        end

        if InventoryMetadata.SkillEdits then
            FinalMetadata.SkillEdits = InventoryMetadata.SkillEdits
        end
    end

    return Definition, FinalMetadata
end

function ActionRegistry.GetAllNames(): { string }
    local Names = {}
    for Name in RegisteredActions do
        table.insert(Names, Name)
    end
    return Names
end

function ActionRegistry.LoadFolder(Folder: Instance)
    local Count = 0
    for _, Child in Folder:GetChildren() do
        if Child:IsA("ModuleScript") and not Child.Name:match("Template") then
            local Success, Result = pcall(require, Child)
            if Success and Result.ActionName then
                ActionRegistry.Register(Result)
                Count += 1
            elseif not Success then
                warn("[ActionRegistry] Failed to load action: " .. Child.Name .. " - " .. tostring(Result))
            end
        end
    end
    return Count
end

return ActionRegistry