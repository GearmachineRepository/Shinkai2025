--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatBalance = require(Shared.Config.Balance.CombatBalance)

local CombatFormulas = {}

function CombatFormulas.GetBlockedDamage(BaseDamage: number): number
	return BaseDamage * (1 - CombatBalance.Blocking.DamageReduction)
end

function CombatFormulas.GetBlockStaminaDrain(BaseDamage: number): number
	local BaseDrain = CombatBalance.Blocking.StaminaDrainOnHit
	local ScaledDrain = BaseDamage * CombatBalance.Blocking.StaminaDrainScalar
	return BaseDrain + ScaledDrain
end

function CombatFormulas.GetBodyPartMultiplier(BodyPart: string): number
	if BodyPart == "Head" then
		return CombatBalance.DamageMultipliers.Head
	elseif BodyPart == "Torso" then
		return CombatBalance.DamageMultipliers.Torso
	elseif BodyPart == "Legs" then
		return CombatBalance.DamageMultipliers.Legs
	end
	return CombatBalance.DamageMultipliers.Torso
end

function CombatFormulas.GetPostureDamage(BaseDamage: number, IsBlocked: boolean): number
	local PostureDamage = CombatBalance.Posture.BaseDamage
	local WeightedDamage = BaseDamage * CombatBalance.Posture.WeightMultiplier

	if IsBlocked then
		return (PostureDamage + WeightedDamage) * CombatBalance.Posture.BlockedMultiplier
	end

	return (PostureDamage + WeightedDamage) * CombatBalance.Posture.HitMultiplier
end

function CombatFormulas.GetPostureRecoveryRate(IsIdle: boolean, TimeSinceLastHit: number): number
	if not IsIdle then
		return 0
	end

	if TimeSinceLastHit < CombatBalance.Posture.IdleDelay then
		return 0
	end

	return CombatBalance.Posture.BaseRecovery
end

function CombatFormulas.IsGuardBroken(CurrentPosture: number): boolean
	return CurrentPosture >= CombatBalance.Posture.Max
end

function CombatFormulas.GetArmorDamageReduction(ArmorType: string, DamageType: string): number
	local ArmorResistances = CombatBalance.ArmorResistances[ArmorType]
	if not ArmorResistances then
		return 0
	end
	return ArmorResistances[DamageType] or 0
end

function CombatFormulas.GetArmorDurabilityLoss(IsHeavyAttack: boolean): number
	if IsHeavyAttack then
		return CombatBalance.Armor.DurabilityLossHeavy
	end
	return CombatBalance.Armor.DurabilityLossLight
end

function CombatFormulas.GetRiposteDamage(BaseDamage: number): number
	return BaseDamage * CombatBalance.Riposte.DamageMultiplier
end

function CombatFormulas.GetMomentumDamage(Velocity: number): number
	if Velocity < CombatBalance.Momentum.Threshold then
		return 0
	end
	return Velocity / CombatBalance.Momentum.DamageDivisor
end

function CombatFormulas.IsWithinBlockAngle(AttackerDirection: Vector3, DefenderLookVector: Vector3): boolean
	local DotProduct = AttackerDirection:Dot(DefenderLookVector)
	local AngleRad = math.acos(math.clamp(DotProduct, -1, 1))
	local AngleDeg = math.deg(AngleRad)
	return AngleDeg <= (CombatBalance.BlockMechanics.ConeAngle / 2)
end

function CombatFormulas.IsWithinParryAngle(AttackerDirection: Vector3, DefenderLookVector: Vector3): boolean
	local DotProduct = AttackerDirection:Dot(DefenderLookVector)
	local AngleRad = math.acos(math.clamp(DotProduct, -1, 1))
	local AngleDeg = math.deg(AngleRad)
	return AngleDeg <= (CombatBalance.ParryMechanics.ConeAngle / 2)
end

function CombatFormulas.GetParryFailPostureDamage(MaxPosture: number): number
	return MaxPosture * CombatBalance.ParryMechanics.FailPosturePercent
end

function CombatFormulas.CalculateFinalDamage(
	BaseDamage: number,
	BodyPart: string,
	ArmorType: string?,
	DamageType: string?,
	IsBlocked: boolean,
	DurabilityReduction: number?
): number
	local Damage = BaseDamage

	Damage = Damage * CombatFormulas.GetBodyPartMultiplier(BodyPart)

	if ArmorType and DamageType then
		local ArmorReduction = CombatFormulas.GetArmorDamageReduction(ArmorType, DamageType)
		Damage = Damage * (1 - ArmorReduction)
	end

	if DurabilityReduction and DurabilityReduction > 0 then
		Damage = Damage * (1 - DurabilityReduction)
	end

	if IsBlocked then
		Damage = CombatFormulas.GetBlockedDamage(Damage)
	end

	return Damage
end

return CombatFormulas