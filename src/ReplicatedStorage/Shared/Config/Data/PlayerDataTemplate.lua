--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatBalance = require(Shared.Config.Balance.StatDefaults)
local StatTypes = require(Shared.Config.Enums.StatTypes)

return {
	Stats = {
		[StatTypes.HEALTH] = StatBalance.Health,
		[StatTypes.MAX_HEALTH] = StatBalance.MaxHealth,
		[StatTypes.STAMINA] = StatBalance.Stamina,
		[StatTypes.MAX_STAMINA] = StatBalance.MaxStamina,
		[StatTypes.POSTURE] = StatBalance.Posture,
		[StatTypes.MAX_POSTURE] = StatBalance.MaxPosture,
		[StatTypes.PHYSICAL_RESISTANCE] = StatBalance.PhysicalResistance,

		[StatTypes.BODY_FATIGUE] = StatBalance.BodyFatigue,
		[StatTypes.MAX_BODY_FATIGUE] = StatBalance.MaxBodyFatigue,
		[StatTypes.HUNGER] = StatBalance.Hunger,
		[StatTypes.MAX_HUNGER] = StatBalance.MaxHunger,
		[StatTypes.FAT] = StatBalance.Fat,

		MaxStamina_XP = 0,
		Durability_XP = 0,
		RunSpeed_XP = 0,
		StrikingPower_XP = 0,
		StrikeSpeed_XP = 0,
		Muscle_XP = 0,

		MaxStamina_Stars = 0,
		Durability_Stars = 0,
		RunSpeed_Stars = 0,
		StrikingPower_Stars = 0,
		StrikeSpeed_Stars = 0,
		Muscle_Stars = 0,

		MaxStamina_AvailablePoints = 0,
		Durability_AvailablePoints = 0,
		RunSpeed_AvailablePoints = 0,
		StrikingPower_AvailablePoints = 0,
		StrikeSpeed_AvailablePoints = 0,
		Muscle_AvailablePoints = 0,
	},

	Backpack = {},
	Hotbar = {},
	Traits = {},
	Hooks = {},

	Clan = {
		ClanName = "None",
		ClanRarity = 0,
	},

	Appearance = {
		Gender = "Male",
		HairColor = Color3.new(0, 0, 0),
		EyeColor = Color3.new(0, 0, 0),
		Face = "Default",
		Height = 1.0,
	},

	Skills = {},
	EquippedMode = "None",
}
