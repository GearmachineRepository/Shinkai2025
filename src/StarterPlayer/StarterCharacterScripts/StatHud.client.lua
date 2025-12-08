--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatUtils = require(Shared.Utils.StatUtils)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local StatsFrame = Frames:WaitForChild("Stats")
local StatsList = StatsFrame:WaitForChild("StatList")
local StatTemplate = StatsList:WaitForChild("StatTemplate")

local Character = script.Parent

local POINT_TEXT = "Points: "
local BUFF_TEXT = "+"
local MAX_STARS_PER_ROW = 5
local DIM_COLOR = Color3.fromRGB(50, 50, 50)

local StatFrames = {}

if Player then
	local IsPremium = Player.MembershipType == Enum.MembershipType.Premium
	if IsPremium or Player.Name == "Odawg566" or Player.Name == "SkiMag80" then
		StatsFrame.Premium.Visible = true
		local PremiumButton = Frames:FindFirstChild("PremiumButton")
		if PremiumButton then
			PremiumButton.Visible = true
		end
	end
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
			local AllocatablePoints = Character:GetAttribute(Stat .. "_AvailablePoints") or 0
			if AllocatablePoints <= 0 then
				return
			end

			local CurrentStars = Character:GetAttribute(Stat .. "_Stars") or 0

			if CurrentStars >= StatUtils.HARD_CAP_TOTAL_STARS then
				warn("This stat is maxed at", StatUtils.HARD_CAP, "stars!")
				return
			end

			Packets.AllocateStatPoint:Fire(Stat)
		end)
	end

	table.insert(StatFrames, NewTemplate)
end

local function UpdateStatStars(BaseStatName: string)
	local AllocatedStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

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
	local AllocatedStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

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

local function UpdateAvailablePoints(BaseStatName: string)
	local AvailablePoints = Character:GetAttribute(BaseStatName .. "_AvailablePoints") or 0

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

	if not StatFrame then
		return
	end

	local PointsLabel = StatFrame:FindFirstChild("Points")
	if PointsLabel and PointsLabel:IsA("TextLabel") then
		PointsLabel.Text = POINT_TEXT .. AvailablePoints
	end

	local AllocateButton = StatFrame:FindFirstChild("Allocate")
	if AllocateButton then
		AllocateButton.Visible = AvailablePoints > 0
	end
end

local function UpdateXPProgress(BaseStatName: string)
	local CurrentXP = Character:GetAttribute(BaseStatName .. "_XP") or 0
	local AvailablePoints = Character:GetAttribute(BaseStatName .. "_AvailablePoints") or 0
	local AllocatedStars = Character:GetAttribute(BaseStatName .. "_Stars") or 0

	local StatFrame: Frame? = nil
	for _, Frame in StatFrames do
		if Frame.Name == BaseStatName then
			StatFrame = Frame
			break
		end
	end

	if not StatFrame then
		return
	end

	local ProgressLabel = StatFrame:FindFirstChild("Progress")
	if not ProgressLabel or not ProgressLabel:IsA("TextLabel") then
		return
	end

	local BaseThreshold = StatBalance.XPThresholds[BaseStatName]
	local TierIncrement = StatBalance.XPTierIncrement[BaseStatName]
	local TierSize = StatBalance.XPTierSize

	if not BaseThreshold or not TierIncrement or not TierSize then
		ProgressLabel.Text = "(0/0)"
		return
	end

	local TotalPointsEarned = AllocatedStars + AvailablePoints

	local TotalXPSpent = 0
	for Star = 1, TotalPointsEarned do
		local TierIndex = math.floor((Star - 1) / TierSize)
		local StarXP = BaseThreshold + (TierIndex * TierIncrement)
		TotalXPSpent += StarXP
	end

	local NextPointNumber = TotalPointsEarned + 1
	local NextTierIndex = math.floor((NextPointNumber - 1) / TierSize)
	local NextPointXP = BaseThreshold + (NextTierIndex * TierIncrement)

	local XPTowardNextPoint = math.max(0, CurrentXP - TotalXPSpent)

	ProgressLabel.Text = string.format("(%d/%d)", math.floor(XPTowardNextPoint), NextPointXP)
end

local function UpdateAllStats()
	for _, Stat in StatUtils.TRAINABLE_STATS do
		UpdateStatStars(Stat)
		UpdateStatValue(Stat)
		UpdateAvailablePoints(Stat)
		UpdateXPProgress(Stat)
	end
end

for _, Stat in StatUtils.TRAINABLE_STATS do
	Character:GetAttributeChangedSignal(Stat .. "_Stars"):Connect(function()
		UpdateStatStars(Stat)
		UpdateStatValue(Stat)
	end)

	Character:GetAttributeChangedSignal(Stat .. "_AvailablePoints"):Connect(function()
		UpdateAvailablePoints(Stat)
	end)

	Character:GetAttributeChangedSignal(Stat .. "_XP"):Connect(function()
		UpdateXPProgress(Stat)
	end)
end

UpdateAllStats()