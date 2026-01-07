--!strict

local UserInputService = game:GetService("UserInputService")

local KeybindDefaults = require(script.Parent.KeybindDefaults)

local INPUT_BUFFER_WINDOW = 0.25
local INPUT_LOOP_INTERVAL = 0.15

type InputState = {
	IsHeld: boolean,
	BufferedAt: number,
	LastLoopTime: number,
}

type KeybindEntry = KeybindDefaults.KeybindEntry
type KeybindTable = KeybindDefaults.KeybindTable
type InputStates = { [Enum.KeyCode | Enum.UserInputType]: InputState }
type InputMode = "PC" | "Console"

local GAMEPAD_INPUT_TYPES: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.Gamepad1] = true,
	[Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true,
	[Enum.UserInputType.Gamepad4] = true,
	[Enum.UserInputType.Gamepad5] = true,
	[Enum.UserInputType.Gamepad6] = true,
	[Enum.UserInputType.Gamepad7] = true,
	[Enum.UserInputType.Gamepad8] = true,
}

local InputStates: InputStates = {}
local Keybinds: KeybindTable = {}
local CurrentInputMode: InputMode?

local ActionCallbacks: { (ActionName: string) -> () } = {}
local ReleaseCallbacks: { (ActionName: string) -> () } = {}

local InputBuffer = {}

local function IsGamepadInput(UserInputType: Enum.UserInputType): boolean
	return GAMEPAD_INPUT_TYPES[UserInputType] == true
end

local function GetInputKey(InputObject: InputObject): Enum.KeyCode | Enum.UserInputType
	local UserInputType = InputObject.UserInputType

	if UserInputType == Enum.UserInputType.Keyboard or IsGamepadInput(UserInputType) then
		return InputObject.KeyCode
	end

	return UserInputType
end

local function GetInputModeFromPreferred(): InputMode
	local Preferred = UserInputService.PreferredInput

	if Preferred == Enum.PreferredInput.Gamepad then
		return "Console"
	end

	return "PC"
end

function InputBuffer.OnAction(Callback: (ActionName: string) -> ())
	table.insert(ActionCallbacks, Callback)
end

function InputBuffer.OnRelease(Callback: (ActionName: string) -> ())
	table.insert(ReleaseCallbacks, Callback)
end

function InputBuffer.LoadKeybinds(KeybindTable: KeybindTable)
	table.clear(Keybinds)
	table.clear(InputStates)

	for Input, Entry in KeybindTable do
		Keybinds[Input] = Entry
		InputStates[Input] = {
			IsHeld = false,
			BufferedAt = 0,
			LastLoopTime = 0,
		}
	end
end

function InputBuffer.GetInputMode(): InputMode
	return CurrentInputMode or "PC"
end

function InputBuffer.BufferAction(ActionName: string)
	for Input, Entry in Keybinds do
		if Entry.ActionName == ActionName then
			local State = InputStates[Input]
			if State then
				State.BufferedAt = os.clock()
			end
			break
		end
	end
end

function InputBuffer.TryExecuteBuffered(ActionName: string): boolean
	for Input, Entry in Keybinds do
		if Entry.ActionName == ActionName then
			local State = InputStates[Input]
			if not State then
				return false
			end

			local TimeSinceBuffer = os.clock() - State.BufferedAt
			if TimeSinceBuffer <= INPUT_BUFFER_WINDOW and State.BufferedAt > 0 then
				State.BufferedAt = 0

				for _, Callback in ActionCallbacks do
					task.spawn(Callback, ActionName)
				end

				return true
			end

			return false
		end
	end

	return false
end

function InputBuffer.ClearBuffer(ActionName: string)
	for Input, Entry in Keybinds do
		if Entry.ActionName == ActionName then
			local State = InputStates[Input]
			if State then
				State.BufferedAt = 0
			end
			break
		end
	end
end

function InputBuffer.ClearAllBuffers()
	for _, State in InputStates do
		State.BufferedAt = 0
	end
end

function InputBuffer.IsHeld(ActionName: string): boolean
	for Input, Entry in Keybinds do
		if Entry.ActionName == ActionName then
			local State = InputStates[Input]
			return State and State.IsHeld or false
		end
	end
	return false
end

function InputBuffer.IsBuffered(ActionName: string): boolean
	for Input, Entry in Keybinds do
		if Entry.ActionName == ActionName then
			local State = InputStates[Input]
			if not State then
				return false
			end

			local TimeSinceBuffer = os.clock() - State.BufferedAt
			return TimeSinceBuffer <= INPUT_BUFFER_WINDOW and State.BufferedAt > 0
		end
	end
	return false
end

local function FireAction(ActionName: string)
	for _, Callback in ActionCallbacks do
		task.spawn(Callback, ActionName)
	end
end

local function FireRelease(ActionName: string)
	for _, Callback in ReleaseCallbacks do
		task.spawn(Callback, ActionName)
	end
end

local function SetInputMode(Mode: InputMode)
	if CurrentInputMode == Mode then
		return
	end

	CurrentInputMode = Mode

	if Mode == "PC" then
		InputBuffer.LoadKeybinds(KeybindDefaults.PC)
	else
		InputBuffer.LoadKeybinds(KeybindDefaults.Console)
	end
end

local function OnInputBegan(InputObject: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	local InputKey = GetInputKey(InputObject)
	local Entry = Keybinds[InputKey]
	local State = InputStates[InputKey]

	if not Entry or not State then
		return
	end

	State.IsHeld = true
	State.LastLoopTime = os.clock()

	FireAction(Entry.ActionName)
end

local function OnInputEnded(InputObject: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	local InputKey = GetInputKey(InputObject)
	local Entry = Keybinds[InputKey]
	local State = InputStates[InputKey]

	if not Entry or not State then
		return
	end

	if State.IsHeld then
		State.IsHeld = false

		if Entry.IsHoldAction then
			FireRelease(Entry.ActionName)
		end
	end
end

local function OnPreferredInputChanged()
	SetInputMode(GetInputModeFromPreferred())
end

UserInputService.InputBegan:Connect(OnInputBegan)
UserInputService.InputEnded:Connect(OnInputEnded)

UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(OnPreferredInputChanged)

task.spawn(function()
	while true do
		task.wait(INPUT_LOOP_INTERVAL)

		for Input, Entry in Keybinds do
			if not Entry.CanLoop then
				continue
			end

			local State = InputStates[Input]
			if not State or not State.IsHeld then
				continue
			end

			local TimeSinceLastLoop = os.clock() - State.LastLoopTime
			if TimeSinceLastLoop >= INPUT_LOOP_INTERVAL then
				State.LastLoopTime = os.clock()
				FireAction(Entry.ActionName)
			end
		end
	end
end)

SetInputMode(GetInputModeFromPreferred())

return InputBuffer