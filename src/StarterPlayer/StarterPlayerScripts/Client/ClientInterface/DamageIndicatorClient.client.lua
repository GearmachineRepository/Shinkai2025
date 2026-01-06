--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local Formulas = require(Shared.Utility.Formulas)

local INDICATOR_LIFETIME = 0.25
local RISE_DISTANCE = 2.5
local SPREAD_RANGE = 1.5

local IndicatorStyles = {
	Normal = {
		TextColor = Color3.fromRGB(255, 255, 255),
		TextStrokeColor = Color3.fromRGB(0, 0, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
	},
	Crit = {
		TextColor = Color3.fromRGB(255, 200, 0),
		TextStrokeColor = Color3.fromRGB(100, 50, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 32,
	},
	Heal = {
		TextColor = Color3.fromRGB(100, 255, 100),
		TextStrokeColor = Color3.fromRGB(0, 100, 0),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
	},
	Blocked = {
		TextColor = Color3.fromRGB(150, 150, 255),
		TextStrokeColor = Color3.fromRGB(50, 50, 100),
		Font = Enum.Font.Gotham,
		TextSize = 20,
	},
}

local function CreateIndicator(_TargetCharacter: Model, DamageAmount: number, WorldPosition: Vector3, IndicatorType: string)
	local Style = IndicatorStyles[IndicatorType] or IndicatorStyles.Normal

	local RandomOffset = Vector3.new(
		math.random(-SPREAD_RANGE * 100, SPREAD_RANGE * 100) / 100,
		0,
		math.random(-SPREAD_RANGE * 100, SPREAD_RANGE * 100) / 100
	)

	local Part = Instance.new("Part")
	Part.Size = Vector3.new(0.1, 0.1, 0.1)
	Part.Position = WorldPosition + RandomOffset
	Part.Anchored = true
	Part.CanCollide = false
	Part.CanQuery = false
	Part.Transparency = 1
	Part.Parent = workspace

	local Billboard = Instance.new("BillboardGui")
	Billboard.Size = UDim2.fromOffset(100, 50)
	Billboard.StudsOffset = Vector3.new(0, 0, 0)
	Billboard.AlwaysOnTop = true
	Billboard.Parent = Part

	local TextLabel = Instance.new("TextLabel")
	TextLabel.Size = UDim2.fromScale(1, 1)
	TextLabel.BackgroundTransparency = 1
	TextLabel.Text = tostring(Formulas.Round(DamageAmount, 2))
	TextLabel.TextColor3 = Style.TextColor
	TextLabel.TextStrokeColor3 = Style.TextStrokeColor
	TextLabel.TextStrokeTransparency = 0
	TextLabel.Font = Style.Font
	TextLabel.TextSize = Style.TextSize
	TextLabel.TextScaled = false
	TextLabel.Parent = Billboard

    task.wait(0.5)

	local RiseTween = TweenService:Create(
		Part,
		TweenInfo.new(INDICATOR_LIFETIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Position = Part.Position + Vector3.new(0, RISE_DISTANCE, 0)}
	)

	local FadeTween = TweenService:Create(
		TextLabel,
		TweenInfo.new(INDICATOR_LIFETIME * 0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, INDICATOR_LIFETIME * 0.5),
		{TextTransparency = 1, TextStrokeTransparency = 1}
	)

	RiseTween:Play()
	FadeTween:Play()

	task.delay(INDICATOR_LIFETIME, function()
		Part:Destroy()
	end)
end

Packets.ShowDamageIndicator.OnClientEvent:Connect(function(
	TargetCharacter: Instance,
	DamageAmount: number,
	WorldPosition: Vector3,
	IndicatorType: string
)
	if not TargetCharacter or not TargetCharacter:IsA("Model") or not TargetCharacter:IsDescendantOf(workspace) then
		return
	end

	CreateIndicator(TargetCharacter :: Model, DamageAmount, WorldPosition, IndicatorType)
end)