--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local HookRegistry = {}

local LoadedHooks: {[string]: any} = {}

function HookRegistry.Get(HookName: string)
	if LoadedHooks[HookName] then
		return LoadedHooks[HookName]
	end

	local HooksFolder = Server.Hooks
	local HookModule = HooksFolder:FindFirstChild(HookName)

	if HookModule then
		local Success, Hook = pcall(require, HookModule)
		if Success then
			LoadedHooks[HookName] = Hook
			return Hook
		else
			warn("Failed to load hook:", HookName, Hook)
		end
	else
		warn("Hook module not found:", HookName)
	end

	return nil
end

function HookRegistry.GetAll(HookNames: {string}): {any}
	local Hooks = {}

	for _, HookName in HookNames do
		local Hook = HookRegistry.Get(HookName)
		if Hook then
			table.insert(Hooks, Hook)
		end
	end

	return Hooks
end

function HookRegistry.Clear()
	LoadedHooks = {}
end

return HookRegistry