--!strict

local SkillConfig = {}

export type HitboxData = {
	Size: Vector3,
	Offset: Vector3,
}

export type SkillDefinition = {
	DisplayName: string,
	Category: string,
	RequiredStyle: string?,

	BaseDamage: number,
	BaseStaminaCost: number,
	BaseHitStun: number,
	BaseKnockback: number?,
	BaseCooldown: number,

	AnimationId: string,
	Hitbox: HitboxData?,

	Flags: { string }?,
	DownState: string?,
	MultiHit: number?,
}

local Skills: { [string]: SkillDefinition } = {
	Flashfire = {
		DisplayName = "Flashfire",
		Category = "Strike",
		RequiredStyle = nil,

		BaseDamage = 18,
		BaseStaminaCost = 15,
		BaseHitStun = 0.4,
		BaseKnockback = 40,
		BaseCooldown = 8,

		AnimationId = "FlashfireAnimation",
		Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },

		Flags = { "Unblockable" },
	},

	IronBreaker = {
		DisplayName = "Iron Breaker",
		Category = "Strike",
		RequiredStyle = "Karate",

		BaseDamage = 25,
		BaseStaminaCost = 20,
		BaseHitStun = 0.6,
		BaseKnockback = 70,
		BaseCooldown = 12,

		AnimationId = "IronBreakerAnimation",
		Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },

		Flags = { "GuardBreak" },
	},

	DevilLance = {
		DisplayName = "Devil Lance",
		Category = "Strike",
		RequiredStyle = "Karate",

		BaseDamage = 15,
		BaseStaminaCost = 18,
		BaseHitStun = 0.35,
		BaseKnockback = 30,
		BaseCooldown = 10,

		AnimationId = "DevilLanceAnimation",
		Hitbox = { Size = Vector3.new(3, 3, 8), Offset = Vector3.new(0, 0, -5) },

		Flags = { "Piercing" },
	},

	RakshsasPalm = {
		DisplayName = "Rakshasa's Palm",
		Category = "Strike",
		RequiredStyle = "Koei",

		BaseDamage = 22,
		BaseStaminaCost = 22,
		BaseHitStun = 0.7,
		BaseKnockback = 50,
		BaseCooldown = 14,

		AnimationId = "RakshsasPalmAnimation",
		Hitbox = { Size = Vector3.new(4, 4, 4), Offset = Vector3.new(0, 0, -2) },

		Flags = { "ArmorPiercing" },
	},

	Weeping = {
		DisplayName = "Weeping Willow",
		Category = "Counter",
		RequiredStyle = "Niko",

		BaseDamage = 12,
		BaseStaminaCost = 12,
		BaseHitStun = 0.5,
		BaseKnockback = 60,
		BaseCooldown = 6,

		AnimationId = "WeepingAnimation",
		Hitbox = { Size = Vector3.new(5, 5, 5), Offset = Vector3.new(0, 0, -3) },

		Flags = { "Counter" },
	},

	Ironbreaker = {
		DisplayName = "Ironbreaker",
		Category = "Strike",
		RequiredStyle = "Niko",

		BaseDamage = 35,
		BaseStaminaCost = 30,
		BaseHitStun = 0.9,
		BaseKnockback = 100,
		BaseCooldown = 18,

		AnimationId = "IronbreakerNikoAnimation",
		Hitbox = { Size = Vector3.new(5, 5, 6), Offset = Vector3.new(0, 0, -4) },

		Flags = { "GuardBreak", "DownState" },
		DownState = "Knockdown",
	},

	LegThrust = {
		DisplayName = "Leg Thrust",
		Category = "Strike",
		RequiredStyle = nil,

		BaseDamage = 16,
		BaseStaminaCost = 14,
		BaseHitStun = 0.4,
		BaseKnockback = 55,
		BaseCooldown = 7,

		AnimationId = "LegThrustAnimation",
		Hitbox = { Size = Vector3.new(4, 5, 7), Offset = Vector3.new(0, 0, -4) },
	},

	GoddoGuro = {
		DisplayName = "God Glow",
		Category = "Strike",
		RequiredStyle = "MuayThai",

		BaseDamage = 30,
		BaseStaminaCost = 25,
		BaseHitStun = 0.8,
		BaseKnockback = 80,
		BaseCooldown = 16,

		AnimationId = "GoddoGuroAnimation",
		Hitbox = { Size = Vector3.new(3, 3, 4), Offset = Vector3.new(0, 0, -2) },

		Flags = { "GuardBreak" },
	},

	Zon = {
		DisplayName = "Zōn",
		Category = "Buff",
		RequiredStyle = nil,

		BaseDamage = 0,
		BaseStaminaCost = 20,
		BaseHitStun = 0,
		BaseKnockback = 0,
		BaseCooldown = 25,

		AnimationId = "ZonAnimation",

		Flags = { "Buff", "NoHitbox" },
	},

	Hachikaiken = {
		DisplayName = "Hachikaiken",
		Category = "Strike",
		RequiredStyle = "Kure",

		BaseDamage = 6,
		BaseStaminaCost = 18,
		BaseHitStun = 0.3,
		BaseKnockback = 35,
		BaseCooldown = 10,

		AnimationId = "HachikaikenAnimation",
		Hitbox = { Size = Vector3.new(5, 5, 5), Offset = Vector3.new(0, 0, -3) },

		MultiHit = 4,
	},

	Jusansatsuken = {
		DisplayName = "Jusansatsuken",
		Category = "Strike",
		RequiredStyle = "Kure",

		BaseDamage = 28,
		BaseStaminaCost = 28,
		BaseHitStun = 0.7,
		BaseKnockback = 90,
		BaseCooldown = 20,

		AnimationId = "JusansatsukenAnimation",
		Hitbox = { Size = Vector3.new(4, 4, 5), Offset = Vector3.new(0, 0, -3) },

		Flags = { "ArmorPiercing" },
	},

	EarthCrouchingDragon = {
		DisplayName = "Earth-Crouching Dragon",
		Category = "Strike",
		RequiredStyle = "Gaoh",

		BaseDamage = 22,
		BaseStaminaCost = 20,
		BaseHitStun = 0.6,
		BaseKnockback = 65,
		BaseCooldown = 12,

		AnimationId = "EarthCrouchingDragonAnimation",
		Hitbox = { Size = Vector3.new(5, 3, 7), Offset = Vector3.new(0, -1, -4) },

		Flags = { "LowStrike" },
	},

	RaishinKick = {
		DisplayName = "Raishin Kick",
		Category = "Strike",
		RequiredStyle = "Raishin",

		BaseDamage = 5,
		BaseStaminaCost = 16,
		BaseHitStun = 0.25,
		BaseKnockback = 30,
		BaseCooldown = 8,

		AnimationId = "RaishinKickAnimation",
		Hitbox = { Size = Vector3.new(4, 6, 6), Offset = Vector3.new(0, 0, -4) },

		MultiHit = 3,
	},
}

function SkillConfig.Get(SkillId: string): SkillDefinition?
	return Skills[SkillId]
end

function SkillConfig.CanUseSkill(SkillId: string, EquippedStyle: string?): boolean
	local Skill = Skills[SkillId]
	if not Skill then
		return false
	end

	if not Skill.RequiredStyle then
		return true
	end

	return Skill.RequiredStyle == EquippedStyle
end

function SkillConfig.SkillExists(SkillId: string): boolean
	return Skills[SkillId] ~= nil
end

function SkillConfig.GetAllSkillIds(): { string }
	local Ids = {}
	for SkillId in Skills do
		table.insert(Ids, SkillId)
	end
	return Ids
end

function SkillConfig.GetSkillsByStyle(StyleName: string): { string }
	local Result = {}
	for SkillId, Skill in Skills do
		if Skill.RequiredStyle == StyleName or Skill.RequiredStyle == nil then
			table.insert(Result, SkillId)
		end
	end
	return Result
end

function SkillConfig.GetSkillsByCategory(Category: string): { string }
	local Result = {}
	for SkillId, Skill in Skills do
		if Skill.Category == Category then
			table.insert(Result, SkillId)
		end
	end
	return Result
end

return SkillConfig