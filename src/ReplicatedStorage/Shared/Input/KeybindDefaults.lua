--!strict

export type KeybindEntry = {
	ActionName: string,
	CanLoop: boolean,
	IsHoldAction: boolean?,
}

export type KeybindTable = { [Enum.KeyCode | Enum.UserInputType]: KeybindEntry }

local KeybindDefaults = {}

KeybindDefaults.PC = {
	[Enum.UserInputType.MouseButton1] = { ActionName = "M1", CanLoop = true, IsHoldAction = false },
	[Enum.UserInputType.MouseButton2] = { ActionName = "M2", CanLoop = false, IsHoldAction = false },

	[Enum.KeyCode.F] = { ActionName = "Block", CanLoop = false, IsHoldAction = true },
	[Enum.KeyCode.Q] = { ActionName = "Dodge", CanLoop = true, IsHoldAction = false },
	[Enum.KeyCode.W] = { ActionName = "Sprint", CanLoop = false, IsHoldAction = true },

	[Enum.KeyCode.One] = { ActionName = "Slot1", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Two] = { ActionName = "Slot2", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Three] = { ActionName = "Slot3", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Four] = { ActionName = "Slot4", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Five] = { ActionName = "Slot5", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Six] = { ActionName = "Slot6", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Seven] = { ActionName = "Slot7", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Eight] = { ActionName = "Slot8", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Nine] = { ActionName = "Slot9", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.Zero] = { ActionName = "Slot10", CanLoop = false, IsHoldAction = false },
} :: KeybindTable

KeybindDefaults.Console = {
	[Enum.KeyCode.ButtonR2] = { ActionName = "M1", CanLoop = true, IsHoldAction = false },
	[Enum.KeyCode.ButtonL2] = { ActionName = "M2", CanLoop = false, IsHoldAction = false },

	[Enum.KeyCode.ButtonL1] = { ActionName = "Block", CanLoop = false, IsHoldAction = true },
	[Enum.KeyCode.ButtonB] = { ActionName = "Dodge", CanLoop = true, IsHoldAction = false },
	[Enum.KeyCode.ButtonL3] = { ActionName = "Sprint", CanLoop = false, IsHoldAction = true },

	[Enum.KeyCode.DPadUp] = { ActionName = "Slot1", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.DPadRight] = { ActionName = "Slot2", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.DPadDown] = { ActionName = "Slot3", CanLoop = false, IsHoldAction = false },
	[Enum.KeyCode.DPadLeft] = { ActionName = "Slot4", CanLoop = false, IsHoldAction = false },
} :: KeybindTable

return KeybindDefaults