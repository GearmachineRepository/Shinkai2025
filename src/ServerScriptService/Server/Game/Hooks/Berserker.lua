--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(Server.Combat.CombatEvents)

return {
	HookName = "Berserker",
	Description = "Deal 15% more damage when below 30% health",

	OnActivate = function(Entity)
		local Connection = Ensemble.Events.Subscribe(CombatEvents.AttackHit, function(EventData)
			if EventData.Entity ~= Entity then
				return
			end

			local StatComponent = Entity:GetComponent("Stats")
			if not StatComponent then
				return
			end

			local CurrentHealth = StatComponent:GetStat("Health") :: number
			local MaxHealth = StatComponent:GetStat("MaxHealth") :: number

			if CurrentHealth / MaxHealth <= 0.30 then
				local BonusDamage = EventData.Damage * 0.15
				local DamageComponent = EventData.Target:GetComponent("Damage")

				if DamageComponent then
					DamageComponent:DealDamage(BonusDamage, Entity.Player, Vector3.zero)
				end
			end
		end)

		return function()
			Connection:Disconnect()
		end
	end,
}