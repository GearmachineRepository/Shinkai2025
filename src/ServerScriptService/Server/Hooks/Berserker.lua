--!nonstrict
local Berserker = {
	Name = "Berserker",
	Description = "Deal 50% more damage below 30% health",
}

function Berserker.Register(Controller)
	local Aura = {}

	local function CreateAura()
		if #Aura > 0 then return end

		local Emitter1 = script.Emitter:Clone()
		Emitter1.Parent = Controller.Character.Head
		Emitter1.Enabled = true
		
		table.insert(Aura, Emitter1)
		
		local Emitter2 = script.Sparks:Clone()
		Emitter2.Parent = Controller.Character.UpperTorso
		Emitter2.Enabled = true

		table.insert(Aura, Emitter2)
	end

	local function RemoveAura()
		if #Aura > 0 then
			for _, Emitter in pairs(Aura) do
				Emitter.Enabled = false
				game.Debris:AddItem(Emitter, 5)
			end
			table.clear(Aura)
		end
	end

	local HealthConnection = Controller.Humanoid.HealthChanged:Connect(function()
		local HealthPercent = Controller.Humanoid.Health / Controller.Humanoid.MaxHealth

		if HealthPercent < 0.3 and #Aura <= 0 then
			CreateAura()
		elseif HealthPercent >= 0.3 and #Aura > 0 then
			RemoveAura()
		end
	end)

	local AttackModifierCleanup = Controller:RegisterAttackModifier(100, function(Damage, _)
		local HealthPercent = Controller.Humanoid.Health / Controller.Humanoid.MaxHealth

		if HealthPercent < 0.3 then
			return Damage * 1.5
		end

		return Damage
	end)

	return function()
		RemoveAura()
		HealthConnection:Disconnect()
		AttackModifierCleanup()
	end
end

return Berserker