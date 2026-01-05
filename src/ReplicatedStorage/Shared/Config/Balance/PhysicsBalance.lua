--!strict

local PhysicsBalance = {
	Dash = {
		StaminaCost = 8,
		CooldownSeconds = 2,
		IFrameWindow = 0.225,
		Duration = 0.25,
		RecoveryPercent = 0.3,
		Speed = 86,
		MaxForce = 50000,
	},

	DodgeCancel = {
		Cooldown = 1.0,
		Endlag = 0.15,
	},

	Knockback = {
		DefaultSpeed = 35,
		DefaultDuration = 0.2,
		MaxForce = 50000,
		VerticalComponent = 0,
		ImpactIFrameDuration = 0.3,
	},
}

return PhysicsBalance