--!strict

local UserInputService = game:GetService("UserInputService")

local INPUT_BUFFER_WINDOW = 0.3
local INPUT_LOOP_INTERVAL = 0.15

type InputState = {
	IsHeld: boolean,
	BufferedAt: number,
	LastLoopTime: number,
}

type KeybindEntry = {
	ActionName: string,
	CanLoop: boolean,
}

local InputStates: { [Enum.KeyCode | Enum.UserInputType]: InputState } = {}
local Keybinds: { [Enum.KeyCode | Enum.UserInputType]: KeybindEntry } = {}

local ActionCallbacks: { (ActionName: string) -> () } = {}

local InputBuffer = {}

local DEFAULT_KEYBINDS = {
	[Enum.UserInputType.MouseButton1] = { ActionName = "M1", CanLoop = true },
	[Enum.UserInputType.MouseButton2] = { ActionName = "M2", CanLoop = false },
	[Enum.KeyCode.F] = { ActionName = "Block", CanLoop = true },
	[Enum.KeyCode.Q] = { ActionName = "Skill1", CanLoop = false },
	[Enum.KeyCode.E] = { ActionName = "Skill2", CanLoop = false },
	[Enum.KeyCode.R] = { ActionName = "Skill3", CanLoop = false },
	[Enum.KeyCode.T] = { ActionName = "Skill4", CanLoop = false },
	[Enum.KeyCode.Y] = { ActionName = "Skill5", CanLoop = false },
	[Enum.KeyCode.U] = { ActionName = "Skill6", CanLoop = false },
}

function InputBuffer.OnAction(Callback: (ActionName: string) -> ())
	table.insert(ActionCallbacks, Callback)
end

function InputBuffer.LoadKeybinds(KeybindTable: { [Enum.KeyCode | Enum.UserInputType]: KeybindEntry })
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

local function FireAction(ActionName: string)
	for _, Callback in ActionCallbacks do
		task.spawn(Callback, ActionName)
	end
end

local function OnInputBegan(InputObject: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	local InputType = if InputObject.UserInputType ~= Enum.UserInputType.Keyboard
		then InputObject.UserInputType
		else InputObject.KeyCode

	local Entry = Keybinds[InputType]
	local State = InputStates[InputType]

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

	local InputType = if InputObject.UserInputType ~= Enum.UserInputType.Keyboard
		then InputObject.UserInputType
		else InputObject.KeyCode

	local State = InputStates[InputType]

	if State then
		State.IsHeld = false
	end
end

UserInputService.InputBegan:Connect(OnInputBegan)
UserInputService.InputEnded:Connect(OnInputEnded)

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

InputBuffer.LoadKeybinds(DEFAULT_KEYBINDS)

return InputBuffer
