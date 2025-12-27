--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(ServerScriptService.Server.Ensemble.Types)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

type StateConfig = Types.StateConfig

local Config: StateConfig = {
	States = {
		[StateTypes.SPRINTING] = {
			Default = false,
			Replication = "All",
			Conflicts = { StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.ATTACKING },
		},

		[StateTypes.JOGGING] = {
			Default = false,
			Replication = "All",
			Conflicts = { StateTypes.BLOCKING, StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.ATTACKING },
		},

		[StateTypes.BLOCKING] = {
			Default = false,
			Replication = "All",
			Conflicts = { StateTypes.SPRINTING, StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.ATTACKING },
		},

		[StateTypes.STUNNED] = {
			Default = false,
			Replication = "All",
			LockMovement = true,
			Conflicts = { StateTypes.SPRINTING, StateTypes.BLOCKING },
		},

		[StateTypes.DOWNED] = {
			Default = false,
			Replication = "All",
			LockMovement = true,
			Conflicts = { StateTypes.SPRINTING, StateTypes.BLOCKING },
		},

		[StateTypes.INVULNERABLE] = {
			Default = false,
			Replication = "Owner",
		},

		[StateTypes.IN_CUTSCENE] = {
			Default = false,
			Replication = "Owner",
			LockMovement = true,
		},

		[StateTypes.ATTACKING] = {
			Default = false,
			Replication = "Owner",
		},

		[StateTypes.ONHIT] = {
			Default = false,
			Replication = "Owner",
		},

		[StateTypes.MOVEMENT_LOCKED] = {
			Default = false,
			Replication = "Owner",
		},

		[StateTypes.DODGING] = {
			Default = false,
			Replication = "All",
			Conflicts = { StateTypes.ATTACKING, StateTypes.BLOCKING },
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
	},
}

return Config