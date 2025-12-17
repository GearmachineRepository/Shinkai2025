--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local HookRegistry = require(Server.Entity.Registry.HookRegistry)
local Maid = require(Shared.General.Maid)

local HookController = {}
HookController.__index = HookController

export type HookController = typeof(setmetatable({} :: {
	Controller: any,
	ActiveHooks: {[string]: any},
	Maid: Maid.MaidSelf,
}, HookController))

function HookController.new(CharacterController: any): HookController
	local self = setmetatable({
		Controller = CharacterController,
		ActiveHooks = {},
		Maid = Maid.new(),
	}, HookController)

	return self
end

function HookController:RegisterHook(HookName: string)
	if self.ActiveHooks[HookName] then
		return
	end

	local Hook = HookRegistry.Get(HookName)
	if not Hook then
		warn("Hook not found:", HookName)
		return
	end

	self.ActiveHooks[HookName] = Hook

	if Hook.OnActivate then
		task.spawn(Hook.OnActivate, self.Controller)
	end
end

function HookController:UnregisterHook(HookName: string)
	local Hook = self.ActiveHooks[HookName]
	if not Hook then
		return
	end

	if Hook.OnDeactivate then
		task.spawn(Hook.OnDeactivate, self.Controller)
	end

	self.ActiveHooks[HookName] = nil
end

function HookController:GetActiveHooks(): {string}
	local HookNames = {}
	for HookName in self.ActiveHooks do
		table.insert(HookNames, HookName)
	end
	return HookNames
end

function HookController:Destroy()
	for HookName in self.ActiveHooks do
		self:UnregisterHook(HookName)
	end

	self.Maid:DoCleaning()
end

return HookController