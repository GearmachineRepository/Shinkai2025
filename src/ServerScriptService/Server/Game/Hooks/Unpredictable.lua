--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)

return {
	HookName = "Unpredictable",
	Description = "Can feint even when normally not allowed, up to 2 times per cooldown",

	OnActivate = function(Entity)
		local ChargesUsed = 0
		local CooldownActive = false

		local FeintConnection = Ensemble.Events.Subscribe(CombatEvents.FeintFailed, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			if CooldownActive then
				return
			end

			if ChargesUsed >= 2 then
				CooldownActive = true
				task.delay(30, function()
					CooldownActive = false
					ChargesUsed = 0
				end)
				return
			end

			ChargesUsed += 1
		end)

		return function()
			FeintConnection:Disconnect()
		end
	end,
}