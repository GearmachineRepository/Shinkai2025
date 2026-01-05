--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
}

local ActiveCooldowns: { [string]: CooldownInfo } = {}

local CooldownsRoot: Frame? = nil

local LOOP_ITERATION = 1 / 30

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
	if not NewBar then return end

	NewFrame.Name = CooldownId
	NewBar.Size = UDim2.fromScale(0, 1)
	NewFrame.Visible = true
	NewFrame.Parent = Root
	return NewFrame
end

local function CleanupCooldown(CooldownId: string)
	local CooldownInfo = ActiveCooldowns[CooldownId]
	if CooldownInfo and CooldownInfo.Frame then
		CooldownInfo.Frame:Destroy()
	end
	ActiveCooldowns[CooldownId] = nil
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
	}

	local Remaining = GetCooldownRemaining(StartTime, Duration)
	Timer.Text = string.format("%s: %.1fs", CooldownId, Remaining)
end)

Packets.ClearCooldown.OnClientEvent:Connect(function(CooldownId: string)
	CleanupCooldown(CooldownId)
end)

UpdateService.Register(function()
	if next(ActiveCooldowns) == nil then
		return
	end

	for CooldownId, CooldownInfo in pairs(ActiveCooldowns) do
		local Remaining = GetCooldownRemaining(CooldownInfo.StartTime, CooldownInfo.Duration)

		if Remaining <= 0 then
			CleanupCooldown(CooldownId)
			continue
		end

		local Progress = 1 - (Remaining / CooldownInfo.Duration)
		CooldownInfo.Bar.Size = UDim2.fromScale(Progress, 1)
		CooldownInfo.Timer.Text = string.format("%s: %.1fs", CooldownId, Remaining)
	end
end, LOOP_ITERATION)

PlayerGui.DescendantRemoving:Connect(function(Descendant)
	for Id, Info in pairs(ActiveCooldowns) do
		if Info.Frame and Info.Frame:IsDescendantOf(Descendant) then
			ActiveCooldowns[Id] = nil
		end
	end
end)
