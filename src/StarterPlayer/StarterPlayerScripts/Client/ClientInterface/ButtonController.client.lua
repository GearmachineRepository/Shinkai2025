--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local BUTTONS_CONTAINER_NAME = "Buttons"
local HUD_NAME = "Hud"
local FRAMES_CONTAINER_NAME = "Frames"
local TOGGLE_BUTTON_NAME = "Toggle"
local UI_SCALE_NAME = "ButtonScale"

local HOVER_SCALE = 1.06
local CLICK_SCALE = 0.94

local HOVER_TWEEN_TIME = 0.10
local LEAVE_TWEEN_TIME = 0.12
local CLICK_DOWN_TIME = 0.06
local CLICK_UP_TIME = 0.10

local HOVER_EASING_STYLE = Enum.EasingStyle.Quad
local HOVER_EASING_DIRECTION = Enum.EasingDirection.Out
local LEAVE_EASING_STYLE = Enum.EasingStyle.Quad
local LEAVE_EASING_DIRECTION = Enum.EasingDirection.Out
local CLICK_EASING_STYLE = Enum.EasingStyle.Back
local CLICK_EASING_DIRECTION = Enum.EasingDirection.Out

type ConnectionList = { RBXScriptConnection }

local BoundButtonFrames: { [Instance]: boolean } = {}
local ConnectionsByFrame: { [Instance]: ConnectionList } = {}

local function GetOrCreateScaleObject(Container: Instance): UIScale
	local ExistingScale = Container:FindFirstChild(UI_SCALE_NAME)
	if ExistingScale and ExistingScale:IsA("UIScale") then
		return ExistingScale
	end

	local NewScale = Instance.new("UIScale")
	NewScale.Name = UI_SCALE_NAME
	NewScale.Scale = 1
	NewScale.Parent = Container
	return NewScale
end

local function TweenScale(
	ScaleObject: UIScale,
	TargetScale: number,
	Duration: number,
	Style: Enum.EasingStyle,
	Direction: Enum.EasingDirection
)
	local TweenInfoObject = TweenInfo.new(Duration, Style, Direction)
	local Tween = TweenService:Create(ScaleObject, TweenInfoObject, {
		Scale = TargetScale,
	})
	Tween:Play()
end

local function FindToggleButton(ButtonFrame: Frame): GuiButton?
	local DirectToggle = ButtonFrame:FindFirstChild(TOGGLE_BUTTON_NAME)
	if DirectToggle and DirectToggle:IsA("GuiButton") then
		return DirectToggle
	end

	local FoundButton = ButtonFrame:FindFirstChildWhichIsA("GuiButton", true)
	if FoundButton and FoundButton:IsA("GuiButton") then
		return FoundButton
	end

	return nil
end

local function GetHudFramesRoot(): Instance?
	local Hud = PlayerGui:FindFirstChild(HUD_NAME)
	if not Hud then
		return nil
	end

	local FramesRoot = Hud:FindFirstChild(FRAMES_CONTAINER_NAME)
	if not FramesRoot then
		return nil
	end

	return FramesRoot
end

local function ToggleTargetFrame(ButtonFrameName: string)
	local FramesRoot = GetHudFramesRoot()
	if not FramesRoot then
		return
	end

	local TargetFrame = FramesRoot:FindFirstChild(ButtonFrameName)
	if not TargetFrame then
		return
	end

	if not TargetFrame:IsA("GuiObject") then
		return
	end

	TargetFrame.Visible = not TargetFrame.Visible
end

local function DisconnectFrameConnections(ButtonFrame: Instance)
	local Connections = ConnectionsByFrame[ButtonFrame]
	if not Connections then
		return
	end

	for _, Connection in ipairs(Connections) do
		Connection:Disconnect()
	end

	ConnectionsByFrame[ButtonFrame] = nil
end

local function BindButtonFrame(ButtonFrame: Frame)
	if BoundButtonFrames[ButtonFrame] then
		return
	end

	local ParentInstance = ButtonFrame.Parent
	if not ParentInstance then
		return
	end

	if ParentInstance.Name ~= BUTTONS_CONTAINER_NAME then
		return
	end

	local ToggleButton = FindToggleButton(ButtonFrame)
	if not ToggleButton then
		return
	end

	BoundButtonFrames[ButtonFrame] = true

	local ScaleObject = GetOrCreateScaleObject(ButtonFrame)
	local IsHovered = false

	local Connections: ConnectionList = {}
	ConnectionsByFrame[ButtonFrame] = Connections

	table.insert(
		Connections,
		ToggleButton.MouseEnter:Connect(function()
			IsHovered = true
			TweenScale(ScaleObject, HOVER_SCALE, HOVER_TWEEN_TIME, HOVER_EASING_STYLE, HOVER_EASING_DIRECTION)
		end)
	)

	table.insert(
		Connections,
		ToggleButton.MouseLeave:Connect(function()
			IsHovered = false
			TweenScale(ScaleObject, 1, LEAVE_TWEEN_TIME, LEAVE_EASING_STYLE, LEAVE_EASING_DIRECTION)
		end)
	)

	table.insert(
		Connections,
		ToggleButton.Activated:Connect(function()
			ToggleTargetFrame(ButtonFrame.Name)

			Sounds.UIClick:Play()

			local ReturnScale = if IsHovered then HOVER_SCALE else 1
			TweenScale(ScaleObject, CLICK_SCALE, CLICK_DOWN_TIME, CLICK_EASING_STYLE, CLICK_EASING_DIRECTION)

			task.delay(CLICK_DOWN_TIME, function()
				if ButtonFrame.Parent == nil then
					return
				end
				TweenScale(ScaleObject, ReturnScale, CLICK_UP_TIME, CLICK_EASING_STYLE, CLICK_EASING_DIRECTION)
			end)
		end)
	)

	table.insert(
		Connections,
		ButtonFrame.AncestryChanged:Connect(function(_, NewParent)
			if NewParent == nil then
				DisconnectFrameConnections(ButtonFrame)
				BoundButtonFrames[ButtonFrame] = nil
			end
		end)
	)
end

local function TryBindInstance(Descendant: Instance)
	if not Descendant:IsA("Frame") then
		return
	end

	BindButtonFrame(Descendant)
end

for _, Descendant in ipairs(PlayerGui:GetDescendants()) do
	TryBindInstance(Descendant)
end

PlayerGui.DescendantAdded:Connect(function(Descendant: Instance)
	TryBindInstance(Descendant)
end)
