--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Helpers = Ensemble.HookHelpers

return {
	HookName = "Berserker",
	Description = "Deal 50% more damage when below 30% health",

	OnActivate = function(Entity)
		return Helpers.ModifyDamageDealt(Entity, function(Damage: number)
			local HealthPercent = Helpers.GetHealthPercent(Entity)

			if HealthPercent < 0.3 then
				return Damage * 1.5
			end

			return Damage
		end)
	end,
}