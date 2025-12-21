--!strict

local Types = require(script.Parent.Parent.Types)

type Entity = Types.Entity
type Connection = Types.Connection

local HookHelpers = {}

function HookHelpers.OnStateEnter(Entity: Entity, StateName: string, Callback: () -> ()): () -> ()
	local Connection = Entity.States:OnStateChanged(StateName, function(IsActive: boolean)
		if IsActive then
			Callback()
		end
	end)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnStateExit(Entity: Entity, StateName: string, Callback: () -> ()): () -> ()
	local Connection = Entity.States:OnStateChanged(StateName, function(IsActive: boolean)
		if not IsActive then
			Callback()
		end
	end)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.WhileState(Entity: Entity, StateName: string, OnEnter: () -> (), OnExit: () -> ()): () -> ()
	local Connection = Entity.States:OnStateChanged(StateName, function(IsActive: boolean)
		if IsActive then
			OnEnter()
		else
			OnExit()
		end
	end)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnStatChanged(
	Entity: Entity,
	StatName: string,
	Callback: (NewValue: number, OldValue: number) -> ()
): () -> ()
	local Connection = Entity.Stats:OnStatChanged(StatName, Callback)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnHealthBelow(Entity: Entity, Threshold: number, Callback: () -> ()): () -> ()
	local HasTriggered = false

	local Connection = Entity.Stats:OnStatChanged("Health", function(NewHealth: number)
		local MaxHealth = Entity.Stats:GetStat("MaxHealth")
		if MaxHealth <= 0 then
			return
		end

		local Percent = NewHealth / MaxHealth

		if Percent < Threshold and not HasTriggered then
			HasTriggered = true
			Callback()
		elseif Percent >= Threshold then
			HasTriggered = false
		end
	end)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.OnHealthAbove(Entity: Entity, Threshold: number, Callback: () -> ()): () -> ()
	local HasTriggered = false

	local Connection = Entity.Stats:OnStatChanged("Health", function(NewHealth: number)
		local MaxHealth = Entity.Stats:GetStat("MaxHealth")
		if MaxHealth <= 0 then
			return
		end

		local Percent = NewHealth / MaxHealth

		if Percent > Threshold and not HasTriggered then
			HasTriggered = true
			Callback()
		elseif Percent <= Threshold then
			HasTriggered = false
		end
	end)

	return function()
		Connection:Disconnect()
	end
end

function HookHelpers.ModifyDamageDealt(Entity: Entity, Modifier: (Damage: number) -> number): () -> ()
	return Entity.Modifiers:Register("Attack", 100, function(Damage: number)
		return Modifier(Damage)
	end)
end

function HookHelpers.ModifyDamageTaken(Entity: Entity, Modifier: (Damage: number) -> number): () -> ()
	return Entity.Modifiers:Register("Damage", 100, function(Damage: number)
		return Modifier(Damage)
	end)
end

function HookHelpers.ModifySpeed(Entity: Entity, Modifier: (Speed: number) -> number): () -> ()
	return Entity.Modifiers:Register("Speed", 100, function(Speed: number)
		return Modifier(Speed)
	end)
end

function HookHelpers.ModifyStaminaCost(Entity: Entity, Modifier: (Cost: number) -> number): () -> ()
	return Entity.Modifiers:Register("StaminaCost", 100, function(Cost: number)
		return Modifier(Cost)
	end)
end

function HookHelpers.ModifyValue(Entity: Entity, ModifierType: string, Priority: number, Modifier: (Value: number) -> number): () -> ()
	return Entity.Modifiers:Register(ModifierType, Priority, function(Value: number)
		return Modifier(Value)
	end)
end

function HookHelpers.CombineCleanups(...: (() -> ())?): () -> ()
	local Cleanups = { ... }

	return function()
		for _, Cleanup in pairs(Cleanups) do
			if Cleanup then
				local Success = pcall(Cleanup)
				local ErrorMessage = if Success then nil else "Unknown error"
				if not Success then
					warn(string.format(Types.EngineName .. "Cleanup failed: %s", tostring(ErrorMessage)))
				end
			end
		end
	end
end

function HookHelpers.Delay(Duration: number, Callback: () -> ()): () -> ()
	local Cancelled = false

	task.delay(Duration, function()
		if not Cancelled then
			Callback()
		end
	end)

	return function()
		Cancelled = true
	end
end

function HookHelpers.Interval(Duration: number, Callback: () -> ()): () -> ()
	local Running = true

	task.spawn(function()
		while Running do
			task.wait(Duration)
			if Running then
				Callback()
			end
		end
	end)

	return function()
		Running = false
	end
end

function HookHelpers.GetHealthPercent(Entity: Entity): number
	local Health = Entity.Stats:GetStat("Health")
	local MaxHealth = Entity.Stats:GetStat("MaxHealth")

	if MaxHealth <= 0 then
		return 0
	end

	return Health / MaxHealth
end

function HookHelpers.GetStaminaPercent(Entity: Entity): number
	local Stamina = Entity.Stats:GetStat("Stamina")
	local MaxStamina = Entity.Stats:GetStat("MaxStamina")

	if MaxStamina <= 0 then
		return 0
	end

	return Stamina / MaxStamina
end

return HookHelpers