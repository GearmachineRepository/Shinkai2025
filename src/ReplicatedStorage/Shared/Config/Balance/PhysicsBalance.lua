--!strict

local PhysicsBalance = {
	Dash = {
		StaminaCost = 8,
		CooldownSeconds = 4.0,
		IFrameWindow = 0,
		Duration = 0.25,
		RecoveryPercent = 0.3,
		Speed = 75,
		MaxForce = 50000,

		ConsecutiveDashes = 3,
		ConsecutiveDiminish = 0.20,
		ConsecutiveCooldown = 0.30,
		ComboResetTime = 2.0,
		ExhaustedDuration = 0.5,
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