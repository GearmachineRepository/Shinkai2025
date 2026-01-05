--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(ServerScriptService.Server.Ensemble.Types)
local StatTypes = require(Shared.Config.Enums.StatTypes)
local StatDefaults = require(Shared.Config.Balance.StatDefaults)

type StatConfig = Types.StatConfig

local Config: StatConfig = {
	Stats = {
		[StatTypes.HEALTH] = {
			Default = StatDefaults.Health,
			Min = 0,
			Max = StatDefaults.MaxHealth,
			Replication = "All",
		},

		[StatTypes.MAX_HEALTH] = {
			Default = StatDefaults.MaxHealth,
			Min = 1,
			Replication = "All",
		},

		[StatTypes.STUNDURATION] = {
			Default = StatDefaults.StunDuration,
			Min = 0,
			Replication = "All",
		},

		[StatTypes.STAMINA] = {
			Default = StatDefaults.Stamina,
			Min = 0,
			Max = StatDefaults.MaxStamina,
			Replication = "Owner",
		},

		[StatTypes.MAX_STAMINA] = {
			Default = StatDefaults.MaxStamina,
			Min = 1,
			Replication = "Owner",
		},

		[StatTypes.HUNGER] = {
			Default = StatDefaults.Hunger,
			Min = 0,
			Max = StatDefaults.MaxHunger,
			Replication = "Owner",
		},

		[StatTypes.MAX_HUNGER] = {
			Default = StatDefaults.MaxHunger,
			Min = 1,
			Replication = "Owner",
		},

		[StatTypes.BODY_FATIGUE] = {
			Default = StatDefaults.BodyFatigue,
			Min = 0,
			Max = StatDefaults.MaxBodyFatigue,
			Replication = "Owner",
		},

		[StatTypes.MAX_BODY_FATIGUE] = {
			Default = StatDefaults.MaxBodyFatigue,
			Min = 1,
			Replication = "None",
		},

		[StatTypes.DURABILITY] = {
			Default = 10,
			Min = 0,
			Replication = "None",
		},

		[StatTypes.RUN_SPEED] = {
			Default = 28,
			Min = 0,
			Replication = "None",
		},

		[StatTypes.STRIKING_POWER] = {
			Default = 10,
			Min = 0,
			Replication = "None",
		},

		[StatTypes.STRIKE_SPEED] = {
			Default = 10,
			Min = 0,
			Replication = "None",
		},

		[StatTypes.MUSCLE] = {
			Default = 0,
			Min = 0,
			Replication = "All",
		},

		[StatTypes.FAT] = {
			Default = StatDefaults.Fat,
			Min = 0,
			Replication = "All",
		},
	},
}

return Config