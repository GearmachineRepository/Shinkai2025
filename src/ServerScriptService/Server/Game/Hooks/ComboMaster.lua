--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)

return {
    HookName = "ComboMaster",
	Description = "Each consecutive hit in a combo increases damage by 5%, up to 25%",

	OnActivate = function(Entity)
		local ComboHits = 0

		local HitConnection = Ensemble.Events.Subscribe(CombatEvents.AttackHit, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			ComboHits = math.min(ComboHits + 1, 5)
			local BonusMultiplier = ComboHits * 0.05
			local BonusDamage = EventData.Damage * BonusMultiplier

			if BonusDamage > 0 then
				local DamageComponent = EventData.Target:GetComponent("Damage")
				if DamageComponent then
					DamageComponent:DealDamage(BonusDamage, Entity.Player, Vector3.zero)
				end
			end
		end)

		local ResetConnection = Ensemble.Events.Subscribe(CombatEvents.ComboReset, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end
			ComboHits = 0
		end)

		local FinishConnection = Ensemble.Events.Subscribe(CombatEvents.ComboFinished, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end
			ComboHits = 0
		end)

		return function()
			HitConnection:Disconnect()
			ResetConnection:Disconnect()
			FinishConnection:Disconnect()
		end
	end,
}