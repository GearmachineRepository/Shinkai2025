--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)

return {
	Stats = {
		[StatTypes.HEALTH] = StatBalance.Defaults.Health,
		[StatTypes.MAX_HEALTH] = StatBalance.Defaults.MaxHealth,
		[StatTypes.STAMINA] = StatBalance.Defaults.Stamina,
		[StatTypes.MAX_STAMINA] = StatBalance.Defaults.MaxStamina,
		[StatTypes.POSTURE] = StatBalance.Defaults.Posture,
		[StatTypes.MAX_POSTURE] = StatBalance.Defaults.MaxPosture,
		[StatTypes.PHYSICAL_RESISTANCE] = StatBalance.Defaults.PhysicalResistance,

		[StatTypes.BODY_FATIGUE] = StatBalance.Defaults.BodyFatigue,
		[StatTypes.MAX_BODY_FATIGUE] = StatBalance.Defaults.MaxBodyFatigue,
		[StatTypes.HUNGER] = StatBalance.Defaults.Hunger,
		[StatTypes.MAX_HUNGER] = StatBalance.Defaults.MaxHunger,
		[StatTypes.FAT] = StatBalance.Defaults.Fat,

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
