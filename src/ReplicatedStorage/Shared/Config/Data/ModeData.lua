--!strict

local ModeData = {
	Removal = {
		Name = "Removal",
		DisplayName = "Rimūbaru",
		Description = "Allows the user to consciously remove the brain's limits on their muscular strength output. This results in their skin turning a deeper red-violet, and makes their blood vessels bulge upon the surface.",
		ClanLocked = {"Kure", "Wu"},
		ActivationKey = Enum.KeyCode.T,

		VisualEffects = {
			SkinColor = Color3.fromRGB(150, 50, 80),
			BulgeBloodVessels = true,
			Aura = "rbxassetid://REMOVAL_AURA",
			ActivationSound = "rbxassetid://REMOVAL_SOUND",
		},

		UIDisplay = {
			Icon = "rbxassetid://REMOVAL_ICON",
			Color = Color3.fromRGB(150, 50, 80),
		},
	},

	Advance = {
		Name = "Advance",
		DisplayName = "Possessing Spirit (Tsukigami)",
		Description = "Overclocks the heart's cardiovascular output to rapidly boost the players metabolic rate. The result increases their velocity, acceleration, torque and, consequently, their damage output.",
		ClanLocked = {"Ohma"},
		ActivationKey = Enum.KeyCode.T,

		VisualEffects = {
			SkinColor = Color3.fromRGB(200, 50, 50),
			Vascularity = true,
			FeralSmile = true,
			HeartbeatSound = "rbxassetid://HEARTBEAT_SOUND",
			HeartbeatVolume = 0.8,
			Aura = "rbxassetid://ADVANCE_AURA",
			ActivationSound = "rbxassetid://ADVANCE_SOUND",
		},

		UIDisplay = {
			Icon = "rbxassetid://ADVANCE_ICON",
			Color = Color3.fromRGB(200, 50, 50),
		},
	},

	Guihan = {
		Name = "Guihan",
		DisplayName = "Guihan (Wu Removal)",
		Description = "Wu clan's enhanced version of Removal, allowing higher percentage output.",
		ClanLocked = {"Wu"},
		ActivationKey = Enum.KeyCode.T,

		VisualEffects = {
			SkinColor = Color3.fromRGB(130, 40, 100),
			BulgeBloodVessels = true,
			IntensifiedAura = true,
			Aura = "rbxassetid://GUIHAN_AURA",
			ActivationSound = "rbxassetid://GUIHAN_SOUND",
		},

		UIDisplay = {
			Icon = "rbxassetid://GUIHAN_ICON",
			Color = Color3.fromRGB(130, 40, 100),
		},
	},

	Flow = {
		Name = "Flow",
		DisplayName = "Flow State",
		Description = "A mental state of being completely immersed in an activity, often called 'being in the zone'. It involves intense focus, a merging of action and awareness, a loss of self-consciousness, and a distorted sense of time, leading to peak performance.",
		ClanLocked = nil,
		ActivationKey = Enum.KeyCode.T,

		VisualEffects = {
			EyeGlow = true,
			FocusedExpression = true,
			SubtleAura = true,
			Aura = "rbxassetid://FLOW_AURA",
			ActivationSound = "rbxassetid://FLOW_SOUND",
		},

		UIDisplay = {
			Icon = "rbxassetid://FLOW_ICON",
			Color = Color3.fromRGB(100, 150, 255),
		},
	},
}

return {
	Definitions = ModeData,
}