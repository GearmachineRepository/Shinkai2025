--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local General = Shared:WaitForChild("General")
local Formulas = require(General:WaitForChild("Formulas"))

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local BarsFrame = Frames:WaitForChild("Bars")
local BarsFolder = BarsFrame:WaitForChild("BarFrames")

local BAR_UPDATE_RATE = 0.05
local LERP_SPEED = 10

type BarData = {
	Frame: Frame,
	Fill: Frame,
	StatName: string,
	Quantity: TextLabel,
	MaxStatName: string,
	CurrentValue: number,
	TargetValue: number,
}

local Bars: {[string]: BarData} = {}

local function SetupBar(BarFrame: Frame)
	local BarName = BarFrame.Name
	local Fill = BarFrame:FindFirstChild("Fill")
	local Quantity = BarFrame:FindFirstChild("Quantity")

	if not Fill or not Fill:IsA("Frame") then
		return
	end

	if not Quantity or not Quantity:IsA("TextLabel") then
		return
	end

	local StatName = BarName
	local MaxStatName = "Max" .. BarName

	Bars[BarName] = {
		Frame = BarFrame,
		Fill = Fill,
		Quantity = Quantity,
		StatName = StatName,
		MaxStatName = MaxStatName,
		CurrentValue = 0,
		TargetValue = 0,
	}
end

local function UpdateBar(BarData: BarData, Humanoid: Humanoid, Character: Model)
	if not Character or not Humanoid then
		return
	end

	local Current = Humanoid:GetAttribute(BarData.StatName) or Character:GetAttribute(BarData.StatName)
	local Max = Humanoid:GetAttribute(BarData.MaxStatName) or Character:GetAttribute(BarData.MaxStatName)

	if BarData.StatName == "Health" then
		Current = Humanoid.Health
		Max = Humanoid.MaxHealth
	end

	if BarData.StatName == "Hunger" then
		local HungerThreshold = Character:GetAttribute("HungerThreshold") or 0
		local ThresholdBar = BarData.Frame:FindFirstChild("Threshold")
		if ThresholdBar and ThresholdBar:IsA("Frame") then
			ThresholdBar.Size = UDim2.fromScale(HungerThreshold, 1)
		end
	end

	if not Current or not Max or Max == 0 then
		return
	end

	BarData.TargetValue = Current / Max
end

local function LerpBar(BarData: BarData, DeltaTime: number)
	BarData.CurrentValue = BarData.CurrentValue + (BarData.TargetValue - BarData.CurrentValue) * math.min(LERP_SPEED * DeltaTime, 1)

	BarData.Fill.Size = UDim2.fromScale(BarData.CurrentValue, 1)
end

local function SetupCharacter(Character: Model)
	local Humanoid = Character:WaitForChild("Humanoid", 5)
	if not Humanoid then
		return
	end

	for _, BarData in Bars do
		UpdateBar(BarData, Humanoid, Character)
		BarData.CurrentValue = BarData.TargetValue
		LerpBar(BarData, 0)
	end

	local LastUpdate = tick()

	local HeartbeatConnection = RunService.Heartbeat:Connect(function()
		local CurrentTime = tick()

		if CurrentTime - LastUpdate >= BAR_UPDATE_RATE then
			for _, BarData in Bars do
				UpdateBar(BarData, Humanoid, Character)
				BarData.Quantity.Text = tostring(math.floor(BarData.TargetValue * 100)) .. "%"
			end
			LastUpdate = CurrentTime
		end

		local DeltaTime = CurrentTime - LastUpdate + BAR_UPDATE_RATE
		for _, BarData in Bars do
			LerpBar(BarData, DeltaTime)
			BarData.Quantity.Text = tostring(math.floor(BarData.TargetValue * 100)) .. "%"
		end

		local BodyFatigueTextLabel = BarsFrame:FindFirstChild("BodyFatiguePercentage", true)
		if BodyFatigueTextLabel then
			local BodyFatigue = Character:GetAttribute("BodyFatigue") or Character:GetAttribute("BodyFatigue") or 0
			local MaxBodyFatigue = Character:GetAttribute("MaxBodyFatigue") or Character:GetAttribute("MaxBodyFatigue") or 100
			local Percentage = (BodyFatigue / MaxBodyFatigue) * 100
			local Rounded = Formulas.Round(Percentage, 1)
			if Rounded % 0.15 == 0 then
				BodyFatigueTextLabel.Text = tostring(Rounded) .. "%"
				if not BodyFatigueTextLabel.TextFits then
					BodyFatigueTextLabel.TextScaled = true
				end
			end
		end
	end)

	Character.Destroying:Connect(function()
		HeartbeatConnection:Disconnect()
	end)
end

for _, Child in BarsFolder:GetChildren() do
	if Child:IsA("Frame") then
		SetupBar(Child)
	end
end

BarsFolder.ChildAdded:Connect(function(Child)
	if Child:IsA("Frame") then
		task.wait()
		SetupBar(Child)

		if Player.Character then
			local Humanoid = Player.Character:FindFirstChild("Humanoid")
			if Humanoid then
				local BarData = Bars[Child.Name]
				if BarData then
					UpdateBar(BarData, Humanoid, Player.Character)
					BarData.CurrentValue = BarData.TargetValue
					LerpBar(BarData, 0)
				end
			end
		end
	end
end)

if Player.Character then
	SetupCharacter(Player.Character)
end

Player.CharacterAdded:Connect(SetupCharacter)