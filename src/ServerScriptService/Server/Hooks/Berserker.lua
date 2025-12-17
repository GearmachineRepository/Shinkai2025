--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local CallbackRegistry = require(Server.Core.CallbackRegistry)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local DebugLogger = require(Shared.Debug.DebugLogger)

local Berserker = {
	Name = "Berserker",
	Description = "Deal 50% more damage below 30% health",
}

function Berserker.OnActivate(Entity: any)
	local Cleanups = {}

	local HealthCallback = CallbackRegistry.Register(StatTypes.HEALTH, function()
		local MaxHealth = Entity.Stats:GetStat(StatTypes.MAX_HEALTH)
		if MaxHealth <= 0 then
			return
		end
	end, Entity.Character)

	table.insert(Cleanups, function()
		HealthCallback:Disconnect()
	end)

	local AttackModifier = Entity.Modifiers:Register("Attack", 100, function(Damage: number, _Data: any)
		local Health = Entity.Stats:GetStat(StatTypes.HEALTH)
		local MaxHealth = Entity.Stats:GetStat(StatTypes.MAX_HEALTH)

		if MaxHealth > 0 and (Health / MaxHealth) < 0.3 then
			DebugLogger.Info(script.Name, "Boosting damage (", 1.5, "x) for:", Entity.Player)
			return Damage * 1.5
		end

		return Damage
	end)

	table.insert(Cleanups, AttackModifier)

	return function()
		DebugLogger.Info(script.Name, "Cleaning for:", Entity.Player)
		for _, CleanupFn in Cleanups do
			if CleanupFn then
				CleanupFn()
			end
		end
	end
end

return Berserker
