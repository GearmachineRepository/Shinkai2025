--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local DebugLogger = require(Shared.Debug.DebugLogger)

local Berserker = {
	Name = "Berserker",
	Description = "Deal 50% more damage below 30% health",
}

function Berserker.OnActivate(Entity: any)
	local Cleanup = {}
	-- local Aura = {}

	-- local function CreateAura()
	-- 	if #Aura > 0 then
	-- 		return
	-- 	end

	-- 	local Emitter1 = script.Emitter:Clone()
	-- 	Emitter1.Parent = Entity.Character.Head
	-- 	Emitter1.Enabled = true
	-- 	table.insert(Aura, Emitter1)

	-- 	local Emitter2 = script.Sparks:Clone()
	-- 	Emitter2.Parent = Entity.Character.UpperTorso
	-- 	Emitter2.Enabled = true
	-- 	table.insert(Aura, Emitter2)
	-- end

	-- local function RemoveAura()
	-- 	if #Aura > 0 then
	-- 		for _, Emitter in Aura do
	-- 			Emitter.Enabled = false
	-- 			game.Debris:AddItem(Emitter, 5)
	-- 		end
	-- 		table.clear(Aura)
	-- 	end
	-- end

	local HealthCallback = Entity.Stats:OnStatChanged(StatTypes.HEALTH, function(_NewHealth: number, _OldHealth: number)
		local MaxHealth = Entity.Stats:GetStat(StatTypes.MAX_HEALTH)
		if MaxHealth <= 0 then
			return
		end

		--local HealthPercent = NewHealth / MaxHealth

		-- if HealthPercent < 0.3 and HealthPercent > 0 then
		-- 	CreateAura()
		-- elseif HealthPercent >= 0.3 then
		-- 	RemoveAura()
		-- end
	end)

	table.insert(Cleanup, HealthCallback)

	local AttackModifier = Entity.Modifiers:Register("Attack", 100, function(Damage: number, _Data: any)
		local Health = Entity.Stats:GetStat(StatTypes.HEALTH)
		local MaxHealth = Entity.Stats:GetStat(StatTypes.MAX_HEALTH)

		if MaxHealth > 0 and (Health / MaxHealth) < 0.3 then
			DebugLogger.Info(script.Name, "Boosting damage (", 1.5, "x) for:", Entity.Player)
			return Damage * 1.5
		end

		return Damage
	end)

	table.insert(Cleanup, AttackModifier)

	return function()
		DebugLogger.Info(script.Name, "Cleaning for:", Entity.Player)
		-- RemoveAura()
		for _, CleanupFn in Cleanup do
			if CleanupFn then
				CleanupFn()
			end
		end
	end
end

return Berserker
