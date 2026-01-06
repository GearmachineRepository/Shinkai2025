--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Helpers = Ensemble.HookHelpers

return {
	HookName = "Cowardly",
	Description = "Receive a 10% run speed buff for 5 seconds at the start of combat",

	OnActivate = function(Entity)
		local SpeedCleanup: (() -> ())? = nil

		local EventConnection = Ensemble.Events.Subscribe("CombatEntered", function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			if SpeedCleanup then
				SpeedCleanup()
			end

			SpeedCleanup = Helpers.ModifySpeed(Entity, function(Speed: number)
				return Speed * 1.10
			end)

			task.delay(5, function()
				if SpeedCleanup then
					SpeedCleanup()
					SpeedCleanup = nil
				end
			end)
		end)

		return function()
			EventConnection:Disconnect()
			if SpeedCleanup then
				SpeedCleanup()
			end
		end
	end,
}