--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Maid = require(Shared.General.Maid)
local DebugLogger = require(Shared.Debug.DebugLogger)

export type HookComponent = {
	Entity: any,

	RegisterHook: (self: HookComponent, HookName: string) -> (),
	UnregisterHook: (self: HookComponent, HookName: string) -> (),
	GetActiveHooks: (self: HookComponent) -> { string },
	HasHook: (self: HookComponent, HookName: string) -> boolean,
	Destroy: (self: HookComponent) -> (),
}

type HookComponentInternal = HookComponent & {
	ActiveHooks: { [string]: any },
	CleanupFunctions: { [string]: () -> () },
	Maid: Maid.MaidSelf,
}

local HookComponent = {}
HookComponent.__index = HookComponent

local LoadedHooks: { [string]: any } = {}

function HookComponent.new(Entity: any): HookComponent
	local self: HookComponentInternal = setmetatable({
		Entity = Entity,
		ActiveHooks = {},
		CleanupFunctions = {},
		Maid = Maid.new(),
	}, HookComponent) :: any

	return self
end

local function LoadHook(HookName: string): any?
	if LoadedHooks[HookName] then
		return LoadedHooks[HookName]
	end

	local HooksFolder = Server:FindFirstChild("Hooks")
	if not HooksFolder then
		return nil
	end

	local HookModule = HooksFolder:FindFirstChild(HookName)
	if not HookModule then
		return nil
	end

	local Success, Hook = pcall(require, HookModule)
	if not Success then
		return nil
	end

	LoadedHooks[HookName] = Hook
	return Hook
end

function HookComponent:RegisterHook(HookName: string)
	if self.ActiveHooks[HookName] then
		return
	end

	local Hook = LoadHook(HookName)
	if not Hook then
		return
	end

	self.ActiveHooks[HookName] = Hook

	if Hook.OnActivate then
		local Success, CleanupOrError = pcall(Hook.OnActivate, self.Entity)

		if not Success then
			self.ActiveHooks[HookName] = nil
			return
		end

		if type(CleanupOrError) == "function" then
			self.CleanupFunctions[HookName] = CleanupOrError
		end
	end
end

function HookComponent:UnregisterHook(HookName: string)
	local Hook = self.ActiveHooks[HookName]
	if not Hook then
		return
	end

	local Cleanup = self.CleanupFunctions[HookName]
	if Cleanup then
		local Success, Error = pcall(Cleanup)
		if not Success then
			DebugLogger.Error("HookComponent", "Hook cleanup failed for %s: %s", HookName, Error)
		end
		self.CleanupFunctions[HookName] = nil
	end

	if Hook.OnDeactivate then
		local Success, Error = pcall(Hook.OnDeactivate, self.Entity)
		if not Success then
			DebugLogger.Error("HookComponent", "Hook deactivation failed for %s: %s", HookName, Error)
		end
	end

	self.ActiveHooks[HookName] = nil
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
