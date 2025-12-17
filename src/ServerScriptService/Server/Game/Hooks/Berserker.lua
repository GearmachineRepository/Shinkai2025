--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local CallbackRegistry = require(Server.Framework.Utilities.CallbackRegistry)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)

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
			return Damage * 1.5
		end

		return Damage
	end)

	table.insert(Cleanups, AttackModifier)

	return function()
		for _, CleanupFn in Cleanups do
			if CleanupFn then
				CleanupFn()
			end
		end
	end
end

return Berserker
