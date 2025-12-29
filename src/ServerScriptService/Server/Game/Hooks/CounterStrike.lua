--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)
local StunManager = require(Server.Combat.StunManager)

return {
	HookName = "CounterStrike",
	Description = "Counter attacks deal 25% more damage and apply a 0.5s longer stun",

	OnActivate = function(Entity)
		local Connection = Ensemble.Events.Subscribe(CombatEvents.CounterHit, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			local BonusDamage = EventData.Damage * 0.25
			local DamageComponent = EventData.Target:GetComponent("Damage")

			if DamageComponent then
				DamageComponent:DealDamage(BonusDamage, Entity.Player, Vector3.zero)
			end

			local TargetStates = EventData.Target:GetComponent("States")
			if TargetStates then
				StunManager.ApplyStun(EventData.Target, 0.5, "PerfectGuard")
			end
		end)

		return function()
			Connection:Disconnect()
		end
	end,
}