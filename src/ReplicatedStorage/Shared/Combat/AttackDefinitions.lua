--!strict

export type AttackDefinition = {
	RangeStuds: number,
	AngleDegrees: number,
	WindupSeconds: number,
	ActiveSeconds: number,
	RecoverySeconds: number,
	Damage: number,
	HitboxSize: Vector3,
	HitboxOffset: Vector3,
}

export type WeaponAttackSet = {
	M1: { AttackDefinition },
}

local DEFAULT_M1: { AttackDefinition } = {
	{
		RangeStuds = 7,
		AngleDegrees = 85,
		WindupSeconds = 0.08,
		ActiveSeconds = 0.18,
		RecoverySeconds = 0.25,
		Damage = 8,
		HitboxSize = Vector3.new(6, 5, 6),
		HitboxOffset = Vector3.new(0, 0, -3.5),
	},
	{
		RangeStuds = 7.5,
		AngleDegrees = 90,
		WindupSeconds = 0.06,
		ActiveSeconds = 0.18,
		RecoverySeconds = 0.28,
		Damage = 9,
		HitboxSize = Vector3.new(6.5, 5, 6.5),
		HitboxOffset = Vector3.new(0, 0, -3.8),
	},
	{
		RangeStuds = 8,
		AngleDegrees = 95,
		WindupSeconds = 0.05,
		ActiveSeconds = 0.20,
		RecoverySeconds = 0.32,
		Damage = 11,
		HitboxSize = Vector3.new(7, 5, 7),
		HitboxOffset = Vector3.new(0, 0, -4.2),
	},
}

local ATTACKS: { [string]: WeaponAttackSet } = {
	Default = {
		M1 = DEFAULT_M1,
	},
}

local function GetWeaponIdOrDefault(WeaponId: string?): string
	if WeaponId == nil or WeaponId == "" then
		return "Default"
	end

	if ATTACKS[WeaponId] == nil then
		return "Default"
	end

	return WeaponId
end

local function GetM1Definition(WeaponId: string?, ComboIndex: number): AttackDefinition
	local ResolvedWeaponId: string = GetWeaponIdOrDefault(WeaponId)
	local WeaponSet: WeaponAttackSet = ATTACKS[ResolvedWeaponId]
	local M1Set: { AttackDefinition } = WeaponSet.M1

	local ClampedIndex: number = math.clamp(ComboIndex, 1, #M1Set)
	return M1Set[ClampedIndex]
end

return {
	GetM1Definition = GetM1Definition,
}
