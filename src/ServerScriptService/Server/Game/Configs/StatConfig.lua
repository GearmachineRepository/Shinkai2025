--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ServerScriptService.Server.Ensemble.Types)

type StatConfig = Types.StatConfig

local Config: StatConfig = {
	Stats = {
		Health = {
			Default = 100,
			Min = 0,
			Replication = "All",
		},

		MaxHealth = {
			Default = 100,
			Min = 1,
			Replication = "All",
		},

		Stamina = {
			Default = 100,
			Min = 0,
			Replication = "Owner",
		},

		MaxStamina = {
			Default = 100,
			Min = 1,
			Replication = "Owner",
		},

		Hunger = {
			Default = 100,
			Min = 0,
			Max = 100,
			Replication = "Owner",
		},

		MaxHunger = {
			Default = 100,
			Min = 1,
			Replication = "Owner",
		},

		BodyFatigue = {
			Default = 0,
			Min = 0,
			Max = 100,
			Replication = "Owner",
		},

		MaxBodyFatigue = {
			Default = 100,
			Min = 1,
			Replication = "None",
		},

		Durability = {
			Default = 10,
			Min = 0,
			Replication = "None",
		},

		RunSpeed = {
			Default = 28,
			Min = 0,
			Replication = "None",
		},

		StrikingPower = {
			Default = 10,
			Min = 0,
			Replication = "None",
		},

		StrikeSpeed = {
			Default = 10,
			Min = 0,
			Replication = "None",
		},

		Muscle = {
			Default = 0,
			Min = 0,
			Replication = "All",
		},

		Fat = {
			Default = 0,
			Min = 0,
			Replication = "All",
		},
	},
}

return Config