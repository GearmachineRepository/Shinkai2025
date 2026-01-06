--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Utility.Formulas)
local UpdateService = require(Shared.Utility.UpdateService)
local Maid = require(Shared.Utility.Maid)
local HudBinder = require(Shared.Utility.HudBinder)

local Player = Players.LocalPlayer

local LERP_SPEED = 12
local UPDATE_INTERVAL = 1 / 30

type BarData = {
	Frame: Frame,
	Fill: Frame,
	StatName: string,
	MaxStatName: string,
	Quantity: TextLabel,
	CurrentValue: number,
	TargetValue: number,
}

type MaidType = {
	GiveTask: (self: MaidType, Task: any) -> (),
	DoCleaning: (self: MaidType) -> (),
}

local BarsByName: { [string]: BarData } = {}

local GuiMaid = (Maid.new() :: any) :: MaidType
local CharacterMaid = (Maid.new() :: any) :: MaidType

local CurrentCharacter: Model? = nil

local Hud: ScreenGui? = nil
local Frames: Instance? = nil
local BarsFrame: Frame? = nil
local BarsFolder: Folder? = nil

local function SetupBar(BarFrame: Frame)
	local BarName = BarFrame.Name
	local FillFrame = BarFrame:FindFirstChild("Fill") :: Frame?
	local QuantityLabel = BarFrame:FindFirstChild("Quantity") :: TextLabel?

	if FillFrame == nil then
		return
	end

	if QuantityLabel == nil then
		return
	end

	BarsByName[BarName] = {
		Frame = BarFrame,
		Fill = FillFrame,
		Quantity = QuantityLabel,
		StatName = BarName,
		MaxStatName = "Max" .. BarName,
		CurrentValue = 0,
		TargetValue = 0,
	}
end

local function UpdateBarTarget(BarInfo: BarData, Humanoid: Humanoid, Character: Model)
	local CurrentValue: number?
	local MaxValue: number?

	if BarInfo.StatName == "Health" then
		CurrentValue = Humanoid.Health
		MaxValue = Humanoid.MaxHealth
	else
		CurrentValue = Humanoid:GetAttribute(BarInfo.StatName) or Character:GetAttribute(BarInfo.StatName)
		MaxValue = Humanoid:GetAttribute(BarInfo.MaxStatName) or Character:GetAttribute(BarInfo.MaxStatName)
	end

	if CurrentValue == nil then
		return
	end

	if MaxValue == nil then
		return
	end

	if MaxValue == 0 then
		return
	end

	BarInfo.TargetValue = CurrentValue / MaxValue

	if BarInfo.StatName == "Hunger" then
		local HungerThreshold = Character:GetAttribute("HungerThreshold") or 0
		local ThresholdFrame = BarInfo.Frame:FindFirstChild("Threshold") :: Frame?

		if ThresholdFrame ~= nil then
			ThresholdFrame.Size = UDim2.fromScale(HungerThreshold, 1)
		end
	end
end

local function LerpBar(BarInfo: BarData, DeltaTime: number)
	local Alpha = math.min(LERP_SPEED * DeltaTime, 1)
	BarInfo.CurrentValue += (BarInfo.TargetValue - BarInfo.CurrentValue) * Alpha
	BarInfo.Fill.Size = UDim2.fromScale(BarInfo.CurrentValue, 1)
	local ClampedValue = math.clamp(BarInfo.CurrentValue, 0, 1)
	local Percentage = math.clamp(math.floor(ClampedValue * 100 + 0.5), 0, 100)
	BarInfo.Quantity.Text = tostring(Percentage) .. "%"
end

local function UpdateBodyFatigue(Character: Model)
	local ActiveBarsFrame = BarsFrame
	if ActiveBarsFrame == nil then
		return
	end

	if ActiveBarsFrame.Parent == nil then
		return
	end

	local BodyFatigueLabel = ActiveBarsFrame:FindFirstChild("BodyFatiguePercentage", true) :: TextLabel?
	if BodyFatigueLabel == nil then
		return
	end

	local BodyFatigueValue = Character:GetAttribute("BodyFatigue") or 0
	local MaxBodyFatigueValue = Character:GetAttribute("MaxBodyFatigue") or 100

	local Percentage = (BodyFatigueValue / MaxBodyFatigueValue) * 100
	local RoundedPercentage = Formulas.Round(Percentage, 1)

	BodyFatigueLabel.Text = tostring(RoundedPercentage) .. "%"
	BodyFatigueLabel.TextScaled = not BodyFatigueLabel.TextFits
end

local function BindGui()
	GuiMaid:DoCleaning()
	table.clear(BarsByName)

	local Refs = HudBinder.Get()
	Hud = Refs.Hud
	Frames = Refs.Frames

	BarsFrame = Frames:WaitForChild("Bars") :: Frame
	BarsFolder = BarsFrame:WaitForChild("BarFrames") :: Folder

	for _, ChildInstance in BarsFolder:GetChildren() do
		if ChildInstance:IsA("Frame") then
			SetupBar(ChildInstance)
		end
	end

	GuiMaid:GiveTask(BarsFolder.ChildAdded:Connect(function(ChildInstance: Instance)
		if not ChildInstance:IsA("Frame") then
			return
		end

		SetupBar(ChildInstance)

		local ActiveCharacter = CurrentCharacter
		if ActiveCharacter == nil then
			return
		end

		if ActiveCharacter.Parent == nil then
			return
		end

		local ActiveHumanoid = ActiveCharacter:FindFirstChildOfClass("Humanoid")
		if ActiveHumanoid == nil then
			return
		end

		local BarInfo = BarsByName[ChildInstance.Name]
		if BarInfo == nil then
			return
		end

		UpdateBarTarget(BarInfo, ActiveHumanoid, ActiveCharacter)
		BarInfo.CurrentValue = BarInfo.TargetValue
		BarInfo.Fill.Size = UDim2.fromScale(BarInfo.CurrentValue, 1)
		BarInfo.Quantity.Text = tostring(math.floor(BarInfo.CurrentValue * 100)) .. "%"
	end))

	GuiMaid:GiveTask(Hud.AncestryChanged:Connect(function(_, Parent)
		if not Parent then
			BindGui()
		end
	end))
end

local function IsGuiValid(): boolean
	if Hud == nil or Hud.Parent == nil then
		return false
	end

	if BarsFrame == nil or BarsFrame.Parent == nil then
		return false
	end

	if BarsFolder == nil or BarsFolder.Parent == nil then
		return false
	end

	return true
end

local function SetupCharacter(Character: Model)
	if not IsGuiValid() then
		BindGui()
	end

	CharacterMaid:DoCleaning()
	CurrentCharacter = Character

	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid?
	if Humanoid == nil then
		return
	end

	for _, BarInfo in BarsByName do
		BarInfo.CurrentValue = 0
		BarInfo.TargetValue = 0

		UpdateBarTarget(BarInfo, Humanoid, Character)

		BarInfo.CurrentValue = BarInfo.TargetValue
		BarInfo.Fill.Size = UDim2.fromScale(BarInfo.CurrentValue, 1)
		BarInfo.Quantity.Text = tostring(math.floor(BarInfo.CurrentValue * 100)) .. "%"
	end

	Character:GetAttributeChangedSignal("InCombat"):Connect(function()
		local Value = Character:GetAttribute("InCombat")
		Player.PlayerGui.Hud.Frames.InCombat.Visible = Value or false
	end)

	local Value = Character:GetAttribute("InCombat")
	Player.PlayerGui.Hud.Frames.InCombat.Visible = Value or false

	local UpdateConnection = UpdateService.Register(function(DeltaTime: number)
		local ActiveCharacter = CurrentCharacter
		if ActiveCharacter == nil then
			return
		end

		if ActiveCharacter.Parent == nil then
			return
		end

		if not IsGuiValid() then
			BindGui()
		end

		local ActiveHumanoid = ActiveCharacter:FindFirstChildOfClass("Humanoid")
		if ActiveHumanoid == nil then
			return
		end

		for _, BarInfo in BarsByName do
			if BarInfo.Frame.Parent == nil then
				continue
			end

			if BarInfo.Fill.Parent == nil then
				continue
			end

			if BarInfo.Quantity.Parent == nil then
				continue
			end

			UpdateBarTarget(BarInfo, ActiveHumanoid, ActiveCharacter)
			LerpBar(BarInfo, DeltaTime)
		end

		UpdateBodyFatigue(ActiveCharacter)
	end, UPDATE_INTERVAL)

	CharacterMaid:GiveTask(UpdateConnection)
end

BindGui()
GuiMaid:GiveTask(HudBinder.OnChanged(function()
	BindGui()
end))

Player.CharacterAdded:Connect(SetupCharacter)

if Player.Character ~= nil then
	SetupCharacter(Player.Character)
end
