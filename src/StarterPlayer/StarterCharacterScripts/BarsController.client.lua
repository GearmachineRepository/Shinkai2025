--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.General.Formulas)
local UpdateService = require(Shared.Networking.UpdateService)
local Maid = require(Shared.General.Maid)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local BarsFrame = Frames:WaitForChild("Bars")
local BarsFolder = BarsFrame:WaitForChild("BarFrames")

local LERP_SPEED = 12
local UPDATE_INTERVAL = 1 / 30

type BarData = {
	Frame: Frame,
	Fill: Frame,
	StatName: string,
	Quantity: TextLabel,
	MaxStatName: string,
	CurrentValue: number,
	TargetValue: number,
}

local Bars: { [string]: BarData } = {}
local CharacterMaid = Maid.new()

local function SetupBar(BarFrame: Frame)
	local BarName = BarFrame.Name
	local Fill = BarFrame:FindFirstChild("Fill") :: Frame?
	local Quantity = BarFrame:FindFirstChild("Quantity") :: TextLabel?

	if not Fill or not Quantity then
		return
	end

	Bars[BarName] = {
		Frame = BarFrame,
		Fill = Fill,
		Quantity = Quantity,
		StatName = BarName,
		MaxStatName = "Max" .. BarName,
		CurrentValue = 0,
		TargetValue = 0,
	}
end

local function UpdateBarTarget(BarData: BarData, Humanoid: Humanoid, Character: Model)
	local Current: number?
	local Max: number?

	if BarData.StatName == "Health" then
		Current = Humanoid.Health
		Max = Humanoid.MaxHealth
	else
		Current = Humanoid:GetAttribute(BarData.StatName) or Character:GetAttribute(BarData.StatName)
		Max = Humanoid:GetAttribute(BarData.MaxStatName) or Character:GetAttribute(BarData.MaxStatName)
	end

	if not Current or not Max or Max == 0 then
		return
	end

	BarData.TargetValue = Current / Max

	if BarData.StatName == "Hunger" then
		local HungerThreshold = Character:GetAttribute("HungerThreshold") or 0
		local ThresholdBar = BarData.Frame:FindFirstChild("Threshold") :: Frame?
		if ThresholdBar then
			ThresholdBar.Size = UDim2.fromScale(HungerThreshold, 1)
		end
	end
end

local function LerpBar(BarData: BarData, DeltaTime: number)
	local Alpha = math.min(LERP_SPEED * DeltaTime, 1)
	BarData.CurrentValue += (BarData.TargetValue - BarData.CurrentValue) * Alpha
	BarData.Fill.Size = UDim2.fromScale(BarData.CurrentValue, 1)
	BarData.Quantity.Text = tostring(math.floor(BarData.CurrentValue * 100)) .. "%"
end

local function UpdateBodyFatigue(Character: Model)
	local BodyFatigueLabel = BarsFrame:FindFirstChild("BodyFatiguePercentage", true) :: TextLabel?
	if not BodyFatigueLabel then
		return
	end

	local BodyFatigue = Character:GetAttribute("BodyFatigue") or 0
	local MaxBodyFatigue = Character:GetAttribute("MaxBodyFatigue") or 100
	local Percentage = (BodyFatigue / MaxBodyFatigue) * 100
	local Rounded = Formulas.Round(Percentage, 1)

	BodyFatigueLabel.Text = tostring(Rounded) .. "%"
	BodyFatigueLabel.TextScaled = not BodyFatigueLabel.TextFits
end

local function SetupCharacter(Character: Model)
	CharacterMaid:DoCleaning()

	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not Humanoid then
		return
	end

	for _, BarData in Bars do
		UpdateBarTarget(BarData, Humanoid, Character)
		BarData.CurrentValue = BarData.TargetValue
		LerpBar(BarData, 0)
	end

	local UpdateConnection = UpdateService.Register(function(DeltaTime: number)
		for _, BarData in Bars do
			UpdateBarTarget(BarData, Humanoid, Character)
			LerpBar(BarData, DeltaTime)
		end

		UpdateBodyFatigue(Character)
	end, UPDATE_INTERVAL)

	CharacterMaid:GiveTask(UpdateConnection)
end

for _, Child in BarsFolder:GetChildren() do
	if Child:IsA("Frame") then
		SetupBar(Child)
	end
end

BarsFolder.ChildAdded:Connect(function(Child)
	if not Child:IsA("Frame") then
		return
	end

	SetupBar(Child)

	if Player.Character then
		local Humanoid = Player.Character:FindFirstChild("Humanoid") :: Humanoid?
		if Humanoid then
			local BarData = Bars[Child.Name]
			if BarData then
				UpdateBarTarget(BarData, Humanoid, Player.Character)
				BarData.CurrentValue = BarData.TargetValue
				LerpBar(BarData, 0)
			end
		end
	end
end)

if Player.Character then
	SetupCharacter(Player.Character)
end

Player.CharacterAdded:Connect(SetupCharacter)
