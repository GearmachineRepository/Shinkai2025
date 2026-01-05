--!strict

local PhysicsBalance = {
	Dash = {
		ConsecutiveDashes = 3,
		StaminaCost = 8,
		CooldownSeconds = 2,
		IFrameWindow = 0,
		Duration = 0.25,
		RecoveryPercent = 0.3,
		Speed = 73,
		MaxForce = 50000,

		ConsecutiveCooldown = 0.35,
		ExhaustedCooldown = 2.5,
		ComboResetTime = 2.0,
		ExhaustedDuration = 0.25,
		MovementSpeedMultiplier = 0.65,
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