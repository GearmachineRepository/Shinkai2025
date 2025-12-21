--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ServerScriptService.Server.Ensemble.Types)

type EventConfig = Types.EventConfig

local Config: EventConfig = {
	Events = {
		"EntityCreated",
		"EntityDestroyed",
		"StateChanged",
		"StatChanged",

		"ModifierAdded",
		"ModifierRemoved",

		"HookActivated",
		"HookDeactivated",

		"DamageTaken",
		"DamageDealt",
		"EntityKilled",
		"EntityDied",

		"StaminaDepleted",
		"StaminaRestored",

		"HungerCritical",
		"HungerRestored",

		"TrainingStarted",
		"TrainingStopped",
		"StatGained",

		"CombatEntered",
		"CombatExited",

		"StatusEffectApplied",
		"StatusEffectRemoved",
		"StatusEffectStacked",
	},
}

return Config