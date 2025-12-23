--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ServerScriptService.Server.Ensemble.Types)

type StateConfig = Types.StateConfig

local Config: StateConfig = {
	States = {
		Sprinting = {
			Default = false,
			Replication = "All",
			Conflicts = { "Blocking", "Stunned", "Downed" },
		},

		Jogging = {
			Default = false,
			Replication = "All",
			Conflicts = { "Blocking", "Stunned", "Downed" },
		},

		Blocking = {
			Default = false,
			Replication = "All",
			Conflicts = { "Sprinting", "Stunned", "Downed" },
		},

		Stunned = {
			Default = false,
			Replication = "All",
			LockMovement = true,
			Conflicts = { "Sprinting", "Blocking" },
		},

		Downed = {
			Default = false,
			Replication = "All",
			LockMovement = true,
			Conflicts = { "Sprinting", "Blocking" },
		},

		Invulnerable = {
			Default = false,
			Replication = "Owner",
		},

		InCombat = {
			Default = false,
			Replication = "All",
		},

		Training = {
			Default = false,
			Replication = "Owner",
		},

		Interacting = {
			Default = false,
			Replication = "None",
			LockMovement = true,
		},

		Exhausted = {
			Default = false,
			Replication = "Owner",
		},

		MovementLocked = {
			Default = false,
			Replication = "Owner",
		},

		Attacking = {
			Default = false,
			Replication = "Owner",
		},
	},
}

return Config