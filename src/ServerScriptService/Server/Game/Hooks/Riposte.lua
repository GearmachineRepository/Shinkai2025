--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)

return {
    HookName = "Riposte",
	Description = "After a successful parry, your next attack deals 50% more damage for 2 seconds",

	OnActivate = function(Entity)
		local RiposteActive = false
		local RiposteCleanup: (() -> ())? = nil

		local ParryConnection = Ensemble.Events.Subscribe(CombatEvents.ParrySuccess, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			RiposteActive = true

			if RiposteCleanup then
				RiposteCleanup()
			end

			local DelayThread = task.delay(2, function()
				RiposteActive = false
			end)

			RiposteCleanup = function()
				task.cancel(DelayThread)
				RiposteActive = false
			end
		end)

		local HitConnection = Ensemble.Events.Subscribe(CombatEvents.AttackHit, function(EventData)
			if EventData.Entity ~= Entity or not RiposteActive then
				return
			end

			local BonusDamage = EventData.Damage * 0.50
			local DamageComponent = EventData.Target:GetComponent("Damage")

			if DamageComponent then
				DamageComponent:DealDamage(BonusDamage, Entity.Player, Vector3.zero)
			end

			RiposteActive = false
		end)

		return function()
			ParryConnection:Disconnect()
			HitConnection:Disconnect()
			if RiposteCleanup then
				RiposteCleanup()
			end
		end
	end,
}