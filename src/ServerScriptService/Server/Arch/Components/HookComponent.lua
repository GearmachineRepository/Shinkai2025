--!strict

local Maid = require(script.Parent.Parent.Utilities.Maid)
local EventBus = require(script.Parent.Parent.Utilities.EventBus)
local Types = require(script.Parent.Parent.Types)

type HookDefinition = Types.HookDefinition

type HookComponentInternal = Types.HookComponent & {
	Entity: any,
	ActiveHooks: { [string]: HookDefinition },
	CleanupFunctions: { [string]: () -> () },
	Maid: Types.Maid,
	HookLoader: any?,
}

local HookComponent = {}
HookComponent.__index = HookComponent

local ActiveHookLoader: any? = nil

function HookComponent.SetHookLoader(Loader: any)
	ActiveHookLoader = Loader
end

function HookComponent.new(Entity: any): Types.HookComponent
	local self: HookComponentInternal = setmetatable({
		Entity = Entity,
		ActiveHooks = {},
		CleanupFunctions = {},
		Maid = Maid.new(),
		HookLoader = ActiveHookLoader,
	}, HookComponent) :: any

	return self
end

function HookComponent:RegisterHook(HookName: string)
	if self.ActiveHooks[HookName] then
		return
	end

	if not self.HookLoader then
		warn(string.format(Types.EngineName .. "HookLoader not configured, cannot load hook: '%s'", HookName))
		return
	end

	local Hook = self.HookLoader.GetHook(HookName)
	if not Hook then
		warn(string.format(Types.EngineName .. "Hook not found: '%s'", HookName))
		return
	end

	self.ActiveHooks[HookName] = Hook

	if Hook.OnActivate then
		local Success, CleanupOrError = pcall(Hook.OnActivate, self.Entity)

		if not Success then
			warn(string.format(Types.EngineName .. "Hook '%s' activation failed: %s", HookName, tostring(CleanupOrError)))
			self.ActiveHooks[HookName] = nil
			return
		end

		if type(CleanupOrError) == "function" then
			self.CleanupFunctions[HookName] = CleanupOrError
		end
	end

	EventBus.Publish("HookActivated", {
		Entity = self.Entity,
		HookName = HookName,
	})
end

function HookComponent:UnregisterHook(HookName: string)
	local Hook = self.ActiveHooks[HookName]
	if not Hook then
		return
	end

	local Cleanup = self.CleanupFunctions[HookName]
	if Cleanup then
		local Success, ErrorMessage = pcall(Cleanup)
		if not Success then
			warn(string.format(Types.EngineName .. "Hook '%s' cleanup failed: %s", HookName, tostring(ErrorMessage)))
		end
		self.CleanupFunctions[HookName] = nil
	end

	if Hook.OnDeactivate then
		local Success, ErrorMessage = pcall(Hook.OnDeactivate, self.Entity)
		if not Success then
			warn(string.format(Types.EngineName .. "Hook '%s' deactivation failed: %s", HookName, tostring(ErrorMessage)))
		end
	end

	self.ActiveHooks[HookName] = nil

	EventBus.Publish("HookDeactivated", {
		Entity = self.Entity,
		HookName = HookName,
	})
end

function HookComponent:GetActiveHooks(): { string }
	local HookNames = {}
	for HookName in self.ActiveHooks do
		table.insert(HookNames, HookName)
	end
	return HookNames
end

function HookComponent:HasHook(HookName: string): boolean
	return self.ActiveHooks[HookName] ~= nil
end

function HookComponent:Destroy()
	for HookName in pairs(self.ActiveHooks) do
		self:UnregisterHook(HookName)
	end

	self.Maid:DoCleaning()
	table.clear(self.ActiveHooks)
	table.clear(self.CleanupFunctions)
end

return HookComponent