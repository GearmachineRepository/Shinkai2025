--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Maid = require(Shared.General.Maid)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local Packets = require(Shared.Networking.Packets)

export type ActionComponent = {
	Entity: any,

	CanPerformAction: (self: ActionComponent, ActionName: string) -> boolean,
	PerformAction: (self: ActionComponent, ActionName: string, ActionData: any?) -> boolean,
	Destroy: (self: ActionComponent) -> (),
}

type ActionComponentInternal = ActionComponent & {
	Maid: Maid.MaidSelf,
	ActionHandlers: { [string]: (Entity: any, ActionData: any?) -> boolean },
}

local ActionComponent = {}
ActionComponent.__index = ActionComponent

function ActionComponent.new(Entity: any): ActionComponent
	local self: ActionComponentInternal = setmetatable({
		Entity = Entity,
		Maid = Maid.new(),
		ActionHandlers = {},
	}, ActionComponent) :: any

	self:RegisterDefaultActions()

	return self
end

function ActionComponent:RegisterDefaultActions()
	self.ActionHandlers.Dash = function(Entity: any, _ActionData: any?): boolean
		if not Entity.Components.StatusEffect then
			return false
		end

		if Entity.Components.StatusEffect:Has("DashCooldown") then
			return false
		end

		if Entity.States:GetState("Stunned") or Entity.States:GetState("Ragdolled") then
			return false
		end

		local StaminaCost = 15
		if Entity.Components.Stamina and not Entity.Components.Stamina:ConsumeStamina(StaminaCost) then
			return false
		end

		Entity.States:SetState("Dashing", true)

		Entity.Components.StatusEffect:Apply("DashCooldown", 1, {
			Stacks = false,
		})

		Packets.ActionApproved:FireClient(Entity.Player, "Dash")

		task.delay(0.2, function()
			if Entity.States then
				Entity.States:SetState("Dashing", false)
			end
		end)

		return true
	end
end

function ActionComponent:CanPerformAction(ActionName: string): boolean
	local Handler = self.ActionHandlers[ActionName]
	if not Handler then
		return false
	end

	if self.Entity.States:GetState("Stunned") or self.Entity.States:GetState("Ragdolled") then
		return false
	end

	return true
end

function ActionComponent:PerformAction(ActionName: string, ActionData: any?): boolean
	if not self:CanPerformAction(ActionName) then
		return false
	end

	local Handler = self.ActionHandlers[ActionName]
	if not Handler then
		return false
	end

	local Success = Handler(self.Entity, ActionData)

	if Success then
		EventBus.Publish(EntityEvents.ACTION_PERFORMED, {
			Entity = self.Entity,
			ActionName = ActionName,
			ActionData = ActionData,
		})
	end

	return Success
end

function ActionComponent:Destroy()
	self.Maid:DoCleaning()
	table.clear(self.ActionHandlers)
end

return ActionComponent
