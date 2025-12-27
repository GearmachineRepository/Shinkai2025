--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(ServerScriptService.Server.Ensemble.Types)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)

type StatConfig = Types.StatConfig

local Config: StatConfig = {
	Stats = {
		[StatTypes.HEALTH] = {
			Default = StatBalance.Defaults.Health,
			Min = 0,
			Max = StatBalance.Defaults.MaxHealth,
			Replication = "All",
		},

		[StatTypes.MAX_HEALTH] = {
			Default = StatBalance.Defaults.MaxHealth,
			Min = 1,
			Replication = "All",
		},

		[StatTypes.STAMINA] = {
			Default = StatBalance.Defaults.Stamina,
			Min = 0,
			Max = StatBalance.Defaults.MaxStamina,
			Replication = "Owner",
		},

		[StatTypes.MAX_STAMINA] = {
			Default = StatBalance.Defaults.MaxStamina,
			Min = 1,
			Replication = "Owner",
		},

		[StatTypes.HUNGER] = {
			Default = StatBalance.Defaults.Hunger,
			Min = 0,
			Max = StatBalance.Defaults.MaxHunger,
			Replication = "Owner",
		},

		[StatTypes.MAX_HUNGER] = {
			Default = StatBalance.Defaults.MaxHunger,
			Min = 1,
			Replication = "Owner",
		},

		[StatTypes.BODY_FATIGUE] = {
			Default = StatBalance.Defaults.BodyFatigue,
			Min = 0,
			Max = StatBalance.Defaults.MaxBodyFatigue,
			Replication = "Owner",
		},

		[StatTypes.MAX_BODY_FATIGUE] = {
			Default = StatBalance.Defaults.MaxBodyFatigue,
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
			Default = StatBalance.Defaults.Fat,
			Min = 0,
			Replication = "All",
		},
	},
}

return Config