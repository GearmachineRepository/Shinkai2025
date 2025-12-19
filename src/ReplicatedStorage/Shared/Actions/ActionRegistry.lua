--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local DashAction = require(Shared.Actions.ActionDefinitions.DashAction)

local ActionRegistry = {}

local RegisteredActions: { [string]: any } = {}

function ActionRegistry.Initialize()
	ActionRegistry.Register(DashAction.new())
end

function ActionRegistry.Register(Action: any)
	if not Action or not Action.Name then
		warn("Cannot register action without Name")
		return
	end

	RegisteredActions[Action.Name] = Action
end

function ActionRegistry.Get(ActionName: string): any?
	return RegisteredActions[ActionName]
end

function ActionRegistry.GetAll(): { [string]: any }
	return RegisteredActions
end

ActionRegistry.Initialize()

return ActionRegistry
