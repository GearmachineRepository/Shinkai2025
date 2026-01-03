--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

export type StateDefinition = {
	Default: boolean?,
	Replication: "All" | "Owner" | "None",
	Conflicts: { string }?,
	LockMovement: boolean?,
	ForceWalk: boolean?,
}

export type ActionDefinition = {
        BlockedBy: { string }?,
        RequiredStates: { string }?,
        AfroDashIgnoredStates: { string }?,
}

export type CombatValidationConfigDefinition = {
	States: { [string]: StateDefinition },
	Actions: { [string]: ActionDefinition },

	GetStateConfig: () -> { States: { [string]: StateDefinition } },
	GetForceWalkStates: () -> { string },
	GetMovementBlockingStates: () -> { string },
	GetConflicts: (StateName: string) -> { string },
}

local CombatValidationConfig = {} :: CombatValidationConfigDefinition

CombatValidationConfig.States = {
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
		ForceWalk = true,
		Conflicts = { StateTypes.SPRINTING, StateTypes.STUNNED, StateTypes.DOWNED, StateTypes.ATTACKING },
	},

	[StateTypes.BLOCK_HIT] = {
		Default = false,
		Replication = "All",
		Conflicts = {},
	},

	[StateTypes.CLASHING] = {
		Default = false,
		Replication = "All",
		Conflicts = {},
	},

	[StateTypes.GUARD_BROKEN] = {
		Default = false,
		Replication = "All",
		LockMovement = true,
		Conflicts = {},
	},

	[StateTypes.STUNNED] = {
		Default = false,
		Replication = "All",
		LockMovement = true,
		ForceWalk = true,
		Conflicts = { StateTypes.SPRINTING, StateTypes.BLOCKING, StateTypes.ATTACKING, StateTypes.DODGING },
	},

	[StateTypes.DOWNED] = {
		Default = false,
		Replication = "All",
		LockMovement = true,
		Conflicts = { StateTypes.SPRINTING, StateTypes.BLOCKING, StateTypes.ATTACKING, StateTypes.DODGING },
	},

	[StateTypes.RAGDOLLED] = {
		Default = false,
		Replication = "All",
		LockMovement = true,
		Conflicts = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.STUNNED },
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
		Replication = "All",
		ForceWalk = true,
		Conflicts = { StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.SPRINTING, StateTypes.JOGGING },
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
		ForceWalk = true,
		Conflicts = { StateTypes.ATTACKING },
	},

	[StateTypes.EXHAUSTED] = {
		Default = false,
		Replication = "All",
		ForceWalk = true,
	},

	[StateTypes.PARRIED] = {
		Default = false,
		Replication = "All",
	},

	PerfectGuardWindow = {
		Default = false,
		Replication = "Owner",
	},

	CounterWindow = {
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
}

CombatValidationConfig.Actions = {
        M1 = {
                BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
			StateTypes.EXHAUSTED,
                        StateTypes.ATTACKING,
                        StateTypes.DODGING,
                        StateTypes.GUARD_BROKEN,
                },
                AfroDashIgnoredStates = { StateTypes.DODGING },
        },

        M2 = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
                        StateTypes.EXHAUSTED,
                        StateTypes.ATTACKING,
                        StateTypes.GUARD_BROKEN,
                },
                AfroDashIgnoredStates = { StateTypes.DODGING },
        },

        LightAttack = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
			StateTypes.EXHAUSTED,
                        StateTypes.ATTACKING,
                        StateTypes.DODGING,
                        StateTypes.GUARD_BROKEN,
                },
                AfroDashIgnoredStates = { StateTypes.DODGING },
        },

        HeavyAttack = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
                        StateTypes.EXHAUSTED,
                        StateTypes.ATTACKING,
                        StateTypes.GUARD_BROKEN,
                },
                AfroDashIgnoredStates = { StateTypes.DODGING },
        },

	Feint = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
			StateTypes.EXHAUSTED,
			StateTypes.GUARD_BROKEN,
		},
	},

	DodgeCancel = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
			StateTypes.EXHAUSTED,
		},
		RequiredStates = { StateTypes.DODGING },
	},

	Block = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
			StateTypes.EXHAUSTED,
			StateTypes.ATTACKING,
			StateTypes.GUARD_BROKEN,
		},
	},

        Dodge = {
                BlockedBy = {
                        StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
                        StateTypes.EXHAUSTED,
                        StateTypes.ATTACKING,
                        StateTypes.DODGING,
                        StateTypes.GUARD_BROKEN,
                },
                AfroDashIgnoredStates = { StateTypes.ATTACKING },
        },

	Skill = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
			StateTypes.EXHAUSTED,
			StateTypes.DODGING,
			StateTypes.GUARD_BROKEN,
		},
	},

	Jog = {
		BlockedBy = {
			StateTypes.ATTACKING,
			StateTypes.BLOCKING,
			StateTypes.STUNNED,
			StateTypes.EXHAUSTED,
			StateTypes.DOWNED,
			StateTypes.DODGING,
			StateTypes.GUARD_BROKEN,
		},
	},

	Run = {
		BlockedBy = {
			StateTypes.ATTACKING,
			StateTypes.BLOCKING,
			StateTypes.STUNNED,
			StateTypes.EXHAUSTED,
			StateTypes.DOWNED,
			StateTypes.DODGING,
			StateTypes.GUARD_BROKEN,
		},
	},

	Hitbox = {
		BlockedBy = {
			StateTypes.STUNNED,
			StateTypes.DOWNED,
			StateTypes.RAGDOLLED,
		},
	},

	Parry = {
		BlockedBy = {},
		RequiredStates = { StateTypes.BLOCKING },
	},
}

function CombatValidationConfig.GetStateConfig(): { States: { [string]: StateDefinition } }
	return { States = CombatValidationConfig.States }
end

function CombatValidationConfig.GetForceWalkStates(): { string }
	local Result = {}
	for StateName, Definition in CombatValidationConfig.States do
		if Definition.ForceWalk then
			table.insert(Result, StateName)
		end
	end
	return Result
end

function CombatValidationConfig.GetMovementBlockingStates(): { string }
	local Result = {}
	for StateName, Definition in CombatValidationConfig.States do
		if Definition.LockMovement then
			table.insert(Result, StateName)
		end
	end
	return Result
end

function CombatValidationConfig.GetConflicts(StateName: string): { string }
	local Definition = CombatValidationConfig.States[StateName]
	if Definition and Definition.Conflicts then
		return Definition.Conflicts
	end
	return {}
end

return CombatValidationConfig
