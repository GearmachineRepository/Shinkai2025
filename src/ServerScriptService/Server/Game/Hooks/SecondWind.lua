--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)

return {
	HookName = "SecondWind",
	Description = "Successful dodges restore 10 stamina",

	OnActivate = function(Entity)
		local Connection = Ensemble.Events.Subscribe(CombatEvents.DamageDodged, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			local StaminaComponent = Entity:GetComponent("Stamina")
			if StaminaComponent then
				StaminaComponent:RestoreStamina(10)
			end
		end)

		return function()
			Connection:Disconnect()
		end
	end,
}