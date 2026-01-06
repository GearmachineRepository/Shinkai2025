--!strict

local CombatTypes = require(script.Parent.Parent.CombatTypes)

type ActionDefinition = CombatTypes.ActionDefinition

local ActionRegistry = {}

local RegisteredActions: { [string]: ActionDefinition } = {}

function ActionRegistry.Register(Definition: ActionDefinition)
	if not Definition.ActionName then
		warn("[ActionRegistry] Cannot register action without ActionName")
		return
	end

	if RegisteredActions[Definition.ActionName] then
		warn("[ActionRegistry] Overwriting existing action: " .. Definition.ActionName)
	end

	RegisteredActions[Definition.ActionName] = Definition
end

function ActionRegistry.Unregister(ActionName: string)
	RegisteredActions[ActionName] = nil
end

function ActionRegistry.Get(ActionName: string): ActionDefinition?
	return RegisteredActions[ActionName]
end

function ActionRegistry.Has(ActionName: string): boolean
	return RegisteredActions[ActionName] ~= nil
end

function ActionRegistry.GetAllNames(): { string }
	local Names = {}
	for Name in RegisteredActions do
		table.insert(Names, Name)
	end
	return Names
end

function ActionRegistry.GetByType(ActionType: string): { ActionDefinition }
	local Matches = {}
	for _, Definition in RegisteredActions do
		if Definition.ActionType == ActionType then
			table.insert(Matches, Definition)
		end
	end
	return Matches
end

function ActionRegistry.LoadFolder(Folder: Instance): number
	local Count = 0

	for _, Child in Folder:GetChildren() do
		if not Child:IsA("ModuleScript") then
			continue
		end

		if Child.Name:match("Template") or Child.Name:match("Types") then
			continue
		end

		local Success, Result = pcall(require, Child)

		if not Success then
			warn("[ActionRegistry] Failed to load action module: " .. Child.Name .. " - " .. tostring(Result))
			continue
		end

		if type(Result) ~= "table" or not Result.ActionName then
			warn("[ActionRegistry] Invalid action module (missing ActionName): " .. Child.Name)
			continue
		end

		ActionRegistry.Register(Result)
		Count += 1
	end

	return Count
end

function ActionRegistry.Clear()
	table.clear(RegisteredActions)
end

return ActionRegistry