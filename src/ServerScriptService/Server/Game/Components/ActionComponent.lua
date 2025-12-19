--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Maid = require(Shared.General.Maid)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local ActionRegistry = require(Shared.Actions.ActionRegistry)
local Packets = require(Shared.Networking.Packets)

export type ActionComponent = {
	Entity: any,

	CanPerformAction: (self: ActionComponent, ActionName: string, ActionData: any?) -> boolean,
	PerformAction: (self: ActionComponent, ActionName: string, ActionData: any?) -> boolean,
	Destroy: (self: ActionComponent) -> (),
}

type ActionComponentInternal = ActionComponent & {
	Maid: Maid.MaidSelf,
	ActiveCooldowns: { [string]: boolean },
}

local ActionComponent = {}
ActionComponent.__index = ActionComponent

function ActionComponent.new(Entity: any): ActionComponent
	local self: ActionComponentInternal = setmetatable({
		Entity = Entity,
		Maid = Maid.new(),
		ActiveCooldowns = {},
	}, ActionComponent) :: any

	return self
end

function ActionComponent:IsOnCooldown(ActionName: string): boolean
	return self.ActiveCooldowns[ActionName] == true
end

function ActionComponent:StartCooldown(ActionName: string, Duration: number)
	self.ActiveCooldowns[ActionName] = true

	task.delay(Duration, function()
		self.ActiveCooldowns[ActionName] = nil
	end)
end

function ActionComponent:CanPerformAction(ActionName: string, ActionData: any?): boolean
	local Action = ActionRegistry.Get(ActionName)
	if not Action then
		return false
	end

	if self:IsOnCooldown(ActionName) then
		return false
	end

	if self.Entity.States:GetState("Stunned") or self.Entity.States:GetState("Ragdolled") then
		return false
	end

	local Context = {
		Entity = self.Entity,
		Character = self.Entity.Character,
		Player = self.Entity.Player,
		ActionData = ActionData,
	}

	local ValidationResult = Action:CanExecute(Context)
	return ValidationResult.Success
end

function ActionComponent:PerformAction(ActionName: string, ActionData: any?): boolean
	if not self:CanPerformAction(ActionName, ActionData) then
		if self.Entity.Player then
			Packets.ActionDenied:FireClient(self.Entity.Player, ActionName)
		end
		return false
	end

	local Action = ActionRegistry.Get(ActionName)
	if not Action then
		return false
	end

	local Context = {
		Entity = self.Entity,
		Character = self.Entity.Character,
		Player = self.Entity.Player,
		ActionData = ActionData,
	}

	local Result = Action:ExecuteServer(Context)

	if Result.Success then
		if Action.CooldownDuration > 0 then
			self:StartCooldown(ActionName, Action.CooldownDuration)

			if self.Entity.Player then
				Packets.StartCooldown:FireClient(
					self.Entity.Player,
					ActionName,
					workspace:GetServerTimeNow(),
					Action.CooldownDuration
				)
			end
		end

		if self.Entity.Player then
			Packets.ActionApproved:FireClient(self.Entity.Player, ActionName)
		end

		EventBus.Publish(EntityEvents.ACTION_PERFORMED, {
			Entity = self.Entity,
			ActionName = ActionName,
			ActionData = ActionData,
		})

		return true
	else
		if self.Entity.Player then
			Packets.ActionDenied:FireClient(self.Entity.Player, ActionName)
		end
		return false
	end
end

function ActionComponent:Destroy()
	self.Maid:DoCleaning()
	table.clear(self.ActiveCooldowns)
end

return ActionComponent
