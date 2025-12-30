--!strict

local MovementModifiers = {}

local EntityModifierRemovers: { [any]: { [string]: (() -> ())? } } = {}

function MovementModifiers.Initialize(Entity: any)
	EntityModifierRemovers[Entity] = {}
end

function MovementModifiers.SetModifier(Entity: any, ModifierId: string, Multiplier: number, Priority: number?)
	if not EntityModifierRemovers[Entity] then
		EntityModifierRemovers[Entity] = {}
	end

	local Remover = EntityModifierRemovers[Entity][ModifierId]
	if Remover then
		Remover()
	end

	local FinalPriority = Priority or 100

	local RemoveModifier = Entity.Modifiers:Register("WalkSpeed", FinalPriority, function(Value: number)
		return Value * Multiplier
	end)

	EntityModifierRemovers[Entity][ModifierId] = RemoveModifier
end

function MovementModifiers.ClearModifier(Entity: any, ModifierId: string)
	if not EntityModifierRemovers[Entity] then
		return
	end

	local Remover = EntityModifierRemovers[Entity][ModifierId]
	if Remover then
		Remover()
		EntityModifierRemovers[Entity][ModifierId] = nil
	end
end

function MovementModifiers.CleanupEntity(Entity: any)
	if not EntityModifierRemovers[Entity] then
		return
	end

	for _, Remover in EntityModifierRemovers[Entity] do
		if Remover then
			Remover()
		end
	end

	EntityModifierRemovers[Entity] = nil
end

return MovementModifiers