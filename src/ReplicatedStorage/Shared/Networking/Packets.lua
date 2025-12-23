--!strict
local Packet = require(script.Parent.Parent:WaitForChild("Packages"):WaitForChild("Packet"))

return {
	-- Animations
	PlayAnimation = Packet("PlayAnimation", Packet.String, Packet.Any),
	StopAnimation = Packet("StopAnimation", Packet.String, Packet.NumberF32),
	-- Equipment
	EquipItem = Packet("EquipItem", Packet.NumberU16, Packet.String),
	UnequipItem = Packet("UnequipItem", Packet.String),

	-- Passives
	TogglePassive = Packet("TogglePassive", Packet.String, Packet.Boolean8),

	-- State Replication
	StateChanged = Packet("StateChanged", Packet.Instance, Packet.String, Packet.Any),
	EventFired = Packet("EventFired", Packet.Instance, Packet.String, Packet.Any),

	-- Footsteps
	Footplanted = Packet("Footplanted", Packet.NumberU8),
	FootplantedReplicate = Packet("FootplantedReplicate", Packet.NumberF64, Packet.NumberU8),

	-- Movement
	MovementStateChanged = Packet("MovementStateChanged", Packet.String),

	-- Food
	ConsumeFood = Packet("ConsumeFood", Packet.NumberF32, Packet.Any),

	-- Stats
	AllocateStatPoint = Packet("AllocateStatPoint", Packet.String),

	-- Treadmill
	TreadmillModeSelected = Packet("TreadmillModeSelected", Packet.Boolean8),
	SelectTreadmillMode = Packet("SelectTreadmillMode", Packet.String),

	-- Interactions
	InteractRequest = Packet("InteractRequest", Packet.Instance, Packet.Boolean8),

	-- Tools
	EquippedTool = Packet("EquippedTool", Packet.NumberU8),
	UnequippedTool = Packet("UnequippedTool", Packet.NumberU8),

	-- Hotbar Sync
	RequestHotbarSync = Packet("RequestHotbarSync"),
	HotbarUpdate = Packet("HotbarUpdate", Packet.Any),
	EquippedToolUpdate = Packet("EquippedToolUpdate", Packet.Any),

	-- Cooldown
	StartCooldown = Packet("StartCooldown", Packet.String, Packet.NumberF64, Packet.NumberF64),
	ClearCooldown = Packet("ClearCooldown", Packet.String),

	-- Action
	PerformAction = Packet("PerformAction", Packet.String, Packet.Any),
	ActionApproved = Packet("ActionApproved", Packet.String),
	ActionDenied = Packet("ActionDenied", Packet.String),

	-- Sounds
	PlaySound = Packet("PlaySound", Packet.String, Packet.Any),
	PlaySoundReplicate = Packet("PlaySoundReplicate", Packet.NumberF64, Packet.String, Packet.Any),

	-- VFX
	PlayVfx = Packet("PlayVfx", Packet.String, Packet.Any),
	PlayVfxReplicate = Packet("PlayVfxReplicate", Packet.NumberF64, Packet.String, Packet.Any),

	-- Combat Actions
	ActionRequest = Packet("ActionRequest", Packet.String, Packet.Any),

	-- Combat Replication
	ActionStarted = Packet("ActionStarted", Packet.Instance, Packet.String, Packet.Any),
	ActionHit = Packet("ActionHit", Packet.Instance, Packet.Instance, Packet.NumberF32),
	ActionInterrupted = Packet("ActionInterrupted", Packet.Instance, Packet.String),
}
