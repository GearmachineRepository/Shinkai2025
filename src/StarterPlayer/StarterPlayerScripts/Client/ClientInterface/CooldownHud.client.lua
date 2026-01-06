--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpdateService = require(Shared.Utility.UpdateService)
local Packets = require(Shared.Networking.Packets)
local HudBinder = require(Shared.Utility.HudBinder)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

type CooldownInfo = {
	StartTime: number,
	Duration: number,
	Frame: Frame,
	Bar: Frame,
	Timer: TextLabel,
	IsFading: boolean,
}

local ActiveCooldowns: { [string]: CooldownInfo } = {}

local CooldownsRoot: Frame? = nil

local LOOP_ITERATION = 1 / 30

local FADE_DURATION_SECONDS = 0.20
local FADE_TWEEN_INFO = TweenInfo.new(FADE_DURATION_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function GetCooldownRemaining(StartTime: number, Duration: number): number
	local Elapsed = workspace:GetServerTimeNow() - StartTime
	return math.max(0, Duration - Elapsed)
end

local function BindGui()
	local Refs = HudBinder.Get()
	local Frames = Refs.Frames
	local Cooldowns = Frames:WaitForChild("Cooldowns") :: Frame
	CooldownsRoot = Cooldowns
end

BindGui()
HudBinder.OnChanged(BindGui)

local function GetOrCreateCooldownFrame(CooldownId: string): Frame?
	local Root = CooldownsRoot
	if Root == nil or Root.Parent == nil then
		return nil
	end

	local ExistingFrame = Root:FindFirstChild(CooldownId)
	if ExistingFrame and ExistingFrame:IsA("Frame") then
		return ExistingFrame
	end

	local Template = Root:FindFirstChild("CooldownTemplate")
	if not Template or not Template:IsA("Frame") then
		return nil
	end

	local NewFrame = Template:Clone()
	local NewBar = NewFrame:FindFirstChild("Bar") :: Frame?
	if not NewBar then
		return nil
	end

	NewFrame.Name = CooldownId
	NewBar.Size = UDim2.fromScale(0, 1)
	NewFrame.Visible = true
	NewFrame.Parent = Root
	return NewFrame
end

local function CreateFadeTweenForGuiObject(GuiObjectInstance: GuiObject): Tween?
	local GoalProperties = {} :: { [string]: any }
	GoalProperties.BackgroundTransparency = 1

	if GuiObjectInstance:IsA("TextLabel") or GuiObjectInstance:IsA("TextButton") or GuiObjectInstance:IsA("TextBox") then
		GoalProperties.TextTransparency = 1
		GoalProperties.TextStrokeTransparency = 1
	end

	if GuiObjectInstance:IsA("ImageLabel") or GuiObjectInstance:IsA("ImageButton") then
		GoalProperties.ImageTransparency = 1
	end

	return TweenService:Create(GuiObjectInstance, FADE_TWEEN_INFO, GoalProperties)
end

local function CreateFadeTweenForUiStroke(UiStrokeInstance: UIStroke): Tween
	return TweenService:Create(UiStrokeInstance, FADE_TWEEN_INFO, { Transparency = 1 })
end

local function FadeOutAndDestroyCooldown(CooldownId: string)
	local CooldownData = ActiveCooldowns[CooldownId]
	if CooldownData == nil then
		return
	end

	if CooldownData.IsFading then
		return
	end

	local CooldownFrame = CooldownData.Frame
	if not CooldownFrame or not CooldownFrame.Parent then
		ActiveCooldowns[CooldownId] = nil
		return
	end

	CooldownData.IsFading = true
	ActiveCooldowns[CooldownId] = CooldownData

	local FadeTweens: { Tween } = {}

	local RootTween = CreateFadeTweenForGuiObject(CooldownFrame)
	if RootTween then
		table.insert(FadeTweens, RootTween)
	end

	for _, DescendantInstance in ipairs(CooldownFrame:GetDescendants()) do
		if DescendantInstance:IsA("GuiObject") then
			local FadeTween = CreateFadeTweenForGuiObject(DescendantInstance)
			if FadeTween then
				table.insert(FadeTweens, FadeTween)
			end
		elseif DescendantInstance:IsA("UIStroke") then
			table.insert(FadeTweens, CreateFadeTweenForUiStroke(DescendantInstance))
		end
	end

	for _, FadeTween in ipairs(FadeTweens) do
		FadeTween:Play()
	end

	if #FadeTweens == 0 then
		CooldownFrame:Destroy()
		ActiveCooldowns[CooldownId] = nil
		return
	end

	local CompletionTween = FadeTweens[1]
	CompletionTween.Completed:Once(function()
		local LatestCooldownData = ActiveCooldowns[CooldownId]
		if LatestCooldownData and LatestCooldownData.Frame == CooldownFrame then
			if CooldownFrame.Parent ~= nil then
				CooldownFrame:Destroy()
			end
			ActiveCooldowns[CooldownId] = nil
		end
	end)
end

Packets.StartCooldown.OnClientEvent:Connect(function(CooldownId: string, StartTime: number, Duration: number)
	local Frame = GetOrCreateCooldownFrame(CooldownId)
	if not Frame then
		return
	end

	local Bar = Frame:FindFirstChild("Bar")
	local Timer = Frame:FindFirstChild("Timer")

	if not Bar or not Bar:IsA("Frame") or not Timer or not Timer:IsA("TextLabel") then
		return
	end

	ActiveCooldowns[CooldownId] = {
		StartTime = StartTime,
		Duration = Duration,
		Frame = Frame,
		Bar = Bar,
		Timer = Timer,
		IsFading = false,
	}

	local Remaining = GetCooldownRemaining(StartTime, Duration)
	Timer.Text = string.format("%s: %.1fs", CooldownId, Remaining)
end)

Packets.ClearCooldown.OnClientEvent:Connect(function(CooldownId: string)
	FadeOutAndDestroyCooldown(CooldownId)
end)

UpdateService.Register(function()
	if next(ActiveCooldowns) == nil then
		return
	end

	for CooldownId, CooldownData in pairs(ActiveCooldowns) do
		if CooldownData.IsFading then
			continue
		end

		local Remaining = GetCooldownRemaining(CooldownData.StartTime, CooldownData.Duration)

		if Remaining <= 0 then
			FadeOutAndDestroyCooldown(CooldownId)
			continue
		end

		local Progress = 1 - (Remaining / CooldownData.Duration)
		CooldownData.Bar.Size = UDim2.fromScale(Progress, 1)
		CooldownData.Timer.Text = string.format("%s: %.1fs", CooldownId, Remaining)
	end
end, LOOP_ITERATION)

PlayerGui.DescendantRemoving:Connect(function(Descendant)
	for CooldownId, CooldownData in pairs(ActiveCooldowns) do
		if CooldownData.Frame and CooldownData.Frame:IsDescendantOf(Descendant) then
			ActiveCooldowns[CooldownId] = nil
		end
	end
end)
