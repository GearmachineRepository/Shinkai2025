--!strict

--[[
    - OnHealthBelow(percent, callback)
    - OnStateChange(state, callback)
    - ModifyDamageDealt(modifier)
    - ModifyDamageTaken(modifier)
    - OnKill(callback)
    - OnDeath(callback)
    - etc.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local CallbackRegistry = require(Server.Framework.Utilities.CallbackRegistry)

local HookHelpers = {}

function HookHelpers.OnHealthBelow(Entity: any, HealthPercent: number, Callback: () -> ()): () -> ()
	local IsBelow = false

	local Connection = CallbackRegistry.Register("StatChanged:Health", function(NewHealth)
		local MaxHealth = Entity.Stats:GetStat("MaxHealth")
		if MaxHealth <= 0 then
			return
		end

		local Percent = NewHealth / MaxHealth

		if Percent < HealthPercent and not IsBelow then
			IsBelow = true
			Callback()
		elseif Percent >= HealthPercent and IsBelow then
			IsBelow = false
		end
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnHealthAbove(Entity: any, HealthPercent: number, Callback: () -> ()): () -> ()
	local IsAbove = false

	local Connection = CallbackRegistry.Register("StatChanged:Health", function(NewHealth)
		local MaxHealth = Entity.Stats:GetStat("MaxHealth")
		if MaxHealth <= 0 then
			return
		end

		local Percent = NewHealth / MaxHealth

		if Percent > HealthPercent and not IsAbove then
			IsAbove = true
			Callback()
		elseif Percent <= HealthPercent and IsAbove then
			IsAbove = false
		end
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnStateEnter(Entity: any, StateName: string, Callback: () -> ()): () -> ()
	local Connection = CallbackRegistry.Register("StateChanged:" .. StateName, function(IsActive)
		if IsActive then
			Callback()
		end
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnStateExit(Entity: any, StateName: string, Callback: () -> ()): () -> ()
	local Connection = CallbackRegistry.Register("StateChanged:" .. StateName, function(IsActive)
		if not IsActive then
			Callback()
		end
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.WhileState(Entity: any, StateName: string, OnEnter: () -> (), OnExit: () -> ()): () -> ()
	local Connection = CallbackRegistry.Register("StateChanged:" .. StateName, function(IsActive)
		if IsActive then
			OnEnter()
		else
			OnExit()
		end
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.ModifyDamageDealt(Entity: any, Modifier: (Damage: number) -> number): () -> ()
	return Entity.Modifiers:Register("Attack", 100, function(Damage)
		return Modifier(Damage)
	end)
end

function HookHelpers.ModifyDamageTaken(Entity: any, Modifier: (Damage: number) -> number): () -> ()
	return Entity.Modifiers:Register("Damage", 100, function(Damage)
		return Modifier(Damage)
	end)
end

function HookHelpers.ModifySpeed(Entity: any, Modifier: (Speed: number) -> number): () -> ()
	return Entity.Modifiers:Register("Speed", 100, function(Speed)
		return Modifier(Speed)
	end)
end

function HookHelpers.ModifyStaminaCost(Entity: any, Modifier: (Cost: number) -> number): () -> ()
	return Entity.Modifiers:Register("StaminaCost", 100, function(Cost)
		return Modifier(Cost)
	end)
end

function HookHelpers.OnDamageTaken(Entity: any, Callback: (DamageAmount: number, Source: any) -> ()): () -> ()
	local Connection = CallbackRegistry.Register("Event:DamageTaken", function(EventData)
		Callback(EventData.Amount, EventData.Source)
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnDamageDealt(Entity: any, Callback: (DamageAmount: number, Target: any) -> ()): () -> ()
	local Connection = CallbackRegistry.Register("Event:DamageDealt", function(EventData)
		Callback(EventData.Amount, EventData.Target)
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnKill(Entity: any, Callback: (Victim: any) -> ()): () -> ()
	local Connection = CallbackRegistry.Register("Event:KilledEnemy", function(EventData)
		Callback(EventData.Victim)
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnDeath(Entity: any, Callback: (Killer: any) -> ()): () -> ()
	local Connection = CallbackRegistry.Register("Event:Died", function(EventData)
		Callback(EventData.Killer)
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnStatChange(
	Entity: any,
	StatName: string,
	Callback: (NewValue: number, OldValue: number) -> ()
): () -> ()
	local Connection = CallbackRegistry.Register("StatChanged:" .. StatName, function(New, Old)
		Callback(New, Old)
	end, Entity.Character)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnSprintStart(Entity: any, Callback: () -> ()): () -> ()
	return HookHelpers.OnStateEnter(Entity, "Sprinting", Callback)
end

function HookHelpers.OnSprintEnd(Entity: any, Callback: () -> ()): () -> ()
	return HookHelpers.OnStateExit(Entity, "Sprinting", Callback)
end

function HookHelpers.OnBlockStart(Entity: any, Callback: () -> ()): () -> ()
	return HookHelpers.OnStateEnter(Entity, "Blocking", Callback)
end

function HookHelpers.OnBlockEnd(Entity: any, Callback: () -> ()): () -> ()
	return HookHelpers.OnStateExit(Entity, "Blocking", Callback)
end

function HookHelpers.CombineCleanups(...: () -> ()): () -> ()
	local Cleanups = { ... }

	return function()
		for _, Cleanup in Cleanups do
			if Cleanup then
				Cleanup()
			end
		end
	end
end

return HookHelpers
