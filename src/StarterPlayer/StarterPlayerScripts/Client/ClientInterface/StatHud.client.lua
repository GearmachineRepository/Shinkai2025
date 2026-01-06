--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatUtils = require(Shared.Utility.StatUtils)
local ProgressionBalance = require(Shared.Config.Balance.ProgressionBalance)
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local POINT_TEXT = "Points: "
local BUFF_TEXT = "+"
local MAX_STARS_PER_ROW = 5
local DIM_COLOR = Color3.fromRGB(50, 50, 50)

local StatFrames: { [string]: Frame } = {}
local CurrentCharacter: Model? = nil
local IsInitialized = false

local Hud: ScreenGui? = nil
local Frames: Instance? = nil
local StatsFrame: Frame? = nil
local StatsList: ScrollingFrame? = nil
local StatTemplate: Frame? = nil

local function WaitForHud(): ScreenGui
	while true do
		local ExistingHud = PlayerGui:FindFirstChild("Hud")
		if ExistingHud then
			return ExistingHud :: ScreenGui
		end

		PlayerGui.ChildAdded:Wait()
	end
end

local function GetXPThresholdForNextPoint(StatName: string, TotalPointsEarned: number): number
	local BaseThreshold = ProgressionBalance.XPThresholds[StatName]
	local TierIncrement = ProgressionBalance.XPTierIncrement[StatName]
	local TierSize = ProgressionBalance.XPTierSize

	if not BaseThreshold or not TierIncrement or not TierSize then
		return 0
	end

	local TierIndex = math.floor(TotalPointsEarned / TierSize)
	return BaseThreshold + (TierIndex * TierIncrement)
end

local function InitializeStatFrames()
	if IsInitialized then
		return
	end

	Hud = WaitForHud()
	if not Hud then
		return
	end
	Frames = Hud:WaitForChild("Frames")
	if not Frames then
		return
	end
	StatsFrame = Frames:WaitForChild("Stats") :: Frame
	if not StatsFrame then
		return
	end
	StatsList = StatsFrame:WaitForChild("StatList") :: ScrollingFrame
	if not StatsList then
		return
	end
	StatTemplate = StatsList:WaitForChild("StatTemplate") :: Frame

	if not StatTemplate then
		return
	end

	for _, Stat in StatUtils.TRAINABLE_STATS do
		local NewTemplate = StatTemplate:Clone()
		NewTemplate.Name = Stat
		NewTemplate.StatName.Text = Stat
		NewTemplate.Visible = true
		NewTemplate.Parent = StatTemplate.Parent

		if not NewTemplate.StatName.TextFits then
			NewTemplate.StatName.TextScaled = true
		end

		local AllocateButton = NewTemplate:FindFirstChild("Allocate")
		local PointsLabel = NewTemplate:FindFirstChild("Points")
		local TotalStatBuffLabel = NewTemplate:FindFirstChild("TotalBuff")
		local ProgressLabel = NewTemplate:FindFirstChild("Progress")

		if PointsLabel then
			PointsLabel.Text = POINT_TEXT .. "0"
		end

		if TotalStatBuffLabel then
			TotalStatBuffLabel.Text = BUFF_TEXT .. "0"
		end

		if ProgressLabel then
			ProgressLabel.Text = "(0/0)"
		end

		if AllocateButton then
			AllocateButton.Visible = false

			AllocateButton.MouseButton1Click:Connect(function()
				if not CurrentCharacter then
					return
				end

				local AllocatablePoints = CurrentCharacter:GetAttribute(Stat .. "_Points") or 0
				if AllocatablePoints <= 0 then
					return
				end

				local CurrentStars = CurrentCharacter:GetAttribute(Stat .. "_Stars") or 0

				if CurrentStars >= StatUtils.HARD_CAP_TOTAL_STARS then
					warn("This stat is maxed at", StatUtils.HARD_CAP_TOTAL_STARS, "stars!")
					return
				end

				Packets.AllocateStatPoint:Fire(Stat)
			end)
		end

		StatFrames[Stat] = NewTemplate
	end

	IsInitialized = true
end

local function UpdateStatStars(BaseStatName: string)
	if not CurrentCharacter then
		return
	end

	local AllocatedStars = CurrentCharacter:GetAttribute(BaseStatName .. "_Stars") or 0
	local StatFrame = StatFrames[BaseStatName]

	if not StatFrame then
		return
	end

	local Stars1 = StatFrame:FindFirstChild("Stars1")
	if not Stars1 then
		return
	end

	for Index = 1, MAX_STARS_PER_ROW do
		local Star = Stars1:FindFirstChild(tostring(Index))
		if Star and Star:IsA("ImageLabel") then
			local HighestTierForPosition = -1

			local CheckStar = Index - 1
			while CheckStar < AllocatedStars do
				HighestTierForPosition = CheckStar
				CheckStar += MAX_STARS_PER_ROW
			end

			if HighestTierForPosition >= 0 then
				local StarTier = StatUtils.GetStarTier(HighestTierForPosition)
				Star.ImageColor3 = StarTier.Color
			else
				Star.ImageColor3 = DIM_COLOR
			end
		end
	end
end

local function UpdateStatValue(BaseStatName: string)
	if not CurrentCharacter then
		return
	end

	local AllocatedStars = CurrentCharacter:GetAttribute(BaseStatName .. "_Stars") or 0
	local StatFrame = StatFrames[BaseStatName]

	if not StatFrame then
		return
	end

	local TotalStatBuffLabel = StatFrame:FindFirstChild("TotalBuff")
	if TotalStatBuffLabel and TotalStatBuffLabel:IsA("TextLabel") then
		local StarBonus = StatUtils.GetStarBonus(BaseStatName)
		local TotalBuff = AllocatedStars * StarBonus

		if TotalBuff % 1 == 0 then
			TotalStatBuffLabel.Text = BUFF_TEXT .. math.floor(TotalBuff)
		else
			TotalStatBuffLabel.Text = BUFF_TEXT .. string.format("%.2f", TotalBuff)
		end
	end
end

local function UpdatePoints(BaseStatName: string)
	if not CurrentCharacter then
		return
	end

	local Points = CurrentCharacter:GetAttribute(BaseStatName .. "_Points") or 0
	local StatFrame = StatFrames[BaseStatName]

	if not StatFrame then
		return
	end

	local PointsLabel = StatFrame:FindFirstChild("Points")
	if PointsLabel and PointsLabel:IsA("TextLabel") then
		PointsLabel.Text = POINT_TEXT .. Points
	end

	local AllocateButton = StatFrame:FindFirstChild("Allocate")
	if AllocateButton then
		AllocateButton.Visible = Points > 0
	end
end

local function UpdateXPProgress(BaseStatName: string)
	if not CurrentCharacter then
		return
	end

	local CurrentXP = CurrentCharacter:GetAttribute(BaseStatName .. "_XP") or 0
	local Points = CurrentCharacter:GetAttribute(BaseStatName .. "_Points") or 0
	local Stars = CurrentCharacter:GetAttribute(BaseStatName .. "_Stars") or 0

	local StatFrame = StatFrames[BaseStatName]

	if not StatFrame then
		return
	end

	local ProgressLabel = StatFrame:FindFirstChild("Progress")
	if not ProgressLabel or not ProgressLabel:IsA("TextLabel") then
		return
	end

	local TotalPointsEarned = Stars + Points
	local Threshold = GetXPThresholdForNextPoint(BaseStatName, TotalPointsEarned)

	if Threshold <= 0 then
		ProgressLabel.Text = "(0/0)"
		return
	end

	ProgressLabel.Text = string.format("(%d/%d)", math.floor(CurrentXP), Threshold)
end

local function UpdateAllStats()
	if not CurrentCharacter then
		return
	end

	for _, Stat in StatUtils.TRAINABLE_STATS do
		UpdateStatStars(Stat)
		UpdateStatValue(Stat)
		UpdatePoints(Stat)
		UpdateXPProgress(Stat)
	end
end

local function SetupCharacterListeners(Character: Model)
	for _, Stat in StatUtils.TRAINABLE_STATS do
		Character:GetAttributeChangedSignal(Stat .. "_Stars"):Connect(function()
			UpdateStatStars(Stat)
			UpdateStatValue(Stat)
			UpdateXPProgress(Stat)
		end)

		Character:GetAttributeChangedSignal(Stat .. "_Points"):Connect(function()
			UpdatePoints(Stat)
			UpdateXPProgress(Stat)
		end)

		Character:GetAttributeChangedSignal(Stat .. "_XP"):Connect(function()
			UpdateXPProgress(Stat)
		end)
	end

	UpdateAllStats()
end

local function OnCharacterAdded(Character: Model)
	CurrentCharacter = Character

	if not IsInitialized then
		InitializeStatFrames()
	end

	SetupCharacterListeners(Character)
end

Player.CharacterAdded:Connect(OnCharacterAdded)

if Player.Character then
	OnCharacterAdded(Player.Character)
end