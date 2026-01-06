--!strict

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local LOCAL_PLAYER: Player = Players.LocalPlayer
local PlayerGui: PlayerGui = LOCAL_PLAYER:WaitForChild("PlayerGui") :: PlayerGui

local MAX_SLOTS: number = 10

local SLOT_SIZE: number = 60
local SLOT_PADDING: number = 8
local HOTBAR_BOTTOM_MARGIN: number = 18

local BACKGROUND_TRANSPARENCY: number = 1
local SLOT_BACKGROUND_TRANSPARENCY: number = 0.5
local SLOT_BACKGROUND_COLOR: Color3 = Color3.fromRGB(12, 12, 12)
local SLOT_TEXT_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local EQUIPPED_BACKGROUND_TRANSPARENCY: number = 0.35
local EQUIPPED_BACKGROUND_COLOR: Color3 = Color3.fromRGB(24, 24, 24)
local UISTROKE_COLOR: Color3 = Color3.fromRGB(255, 255, 255)
local UISTROKE_TRANSPARENCY: number = 0.25

local KEYCODE_TO_SLOT: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
	[Enum.KeyCode.Zero] = 10,
}

type SlotUi = {
	SlotFrame: Frame,
	IconImage: ImageLabel,
	NameLabel: TextLabel,
	KeyLabel: TextLabel,
	CooldownOverlay: Frame,
}

type HotbarItem = {
	ToolId: string,
	ToolName: string,
	Icon: string,
}

local HotbarGui: ScreenGui? = nil
local RootFrame: Frame? = nil
local SlotsFrame: Frame? = nil
local SlotUis: { SlotUi } = {}

local HotbarItems: { [number]: HotbarItem } = {}
local EquippedSlot: number? = nil

local function GetVisibleSlotCount(): number
	local Count: number = 0
	for SlotIndex: number = 1, MAX_SLOTS do
		if HotbarItems[SlotIndex] ~= nil then
			Count += 1
		end
	end
	return Count
end

local function ApplyLayoutVisibility(): ()
	local CurrentRootFrame: Frame? = RootFrame
	if CurrentRootFrame == nil then
		return
	end

	local VisibleCount: number = GetVisibleSlotCount()

	if VisibleCount <= 0 then
		CurrentRootFrame.Visible = false
		return
	end

	CurrentRootFrame.Visible = true

	local TotalWidth: number = (VisibleCount * SLOT_SIZE) + ((VisibleCount + 1) * SLOT_PADDING)
	local TotalHeight: number = SLOT_SIZE + (SLOT_PADDING * 2) + HOTBAR_BOTTOM_MARGIN

	CurrentRootFrame.Size = UDim2.fromOffset(TotalWidth, TotalHeight)
end

local function SetSlotVisual(SlotIndex: number, Item: HotbarItem?): ()
	local SlotUiValue: SlotUi? = SlotUis[SlotIndex]
	if SlotUiValue == nil then
		return
	end

	if Item == nil then
		SlotUiValue.IconImage.Image = ""
		SlotUiValue.NameLabel.Text = ""
		SlotUiValue.CooldownOverlay.Visible = false
		SlotUiValue.SlotFrame.Visible = false
		SlotUiValue.SlotFrame.BackgroundTransparency = SLOT_BACKGROUND_TRANSPARENCY
		return
	end

	SlotUiValue.SlotFrame.Visible = true
	SlotUiValue.IconImage.Image = Item.Icon
	SlotUiValue.NameLabel.Text = Item.ToolName
	SlotUiValue.CooldownOverlay.Visible = false

	local UIStroke = SlotUiValue.SlotFrame:FindFirstChild("UIStroke") :: UIStroke?
	if not UIStroke then return end

	if EquippedSlot == SlotIndex then
		SlotUiValue.SlotFrame.BackgroundTransparency = EQUIPPED_BACKGROUND_TRANSPARENCY
		SlotUiValue.SlotFrame.BackgroundColor3 = EQUIPPED_BACKGROUND_COLOR
		UIStroke.Thickness = 1
	else
		SlotUiValue.SlotFrame.BackgroundTransparency = SLOT_BACKGROUND_TRANSPARENCY
		UIStroke.Thickness = 0
	end
end

local function RefreshAllSlots(): ()
	for SlotIndex: number = 1, MAX_SLOTS do
		SetSlotVisual(SlotIndex, HotbarItems[SlotIndex])
	end
	ApplyLayoutVisibility()
end

local function EquipToolAtSlot(SlotIndex: number): ()
	local Item: HotbarItem? = HotbarItems[SlotIndex]
	if Item == nil then
		return
	end

	if EquippedSlot == SlotIndex then
		Packets.UnequippedTool:Fire(SlotIndex)
		EquippedSlot = nil
	else
		Packets.EquippedTool:Fire(SlotIndex)
		EquippedSlot = SlotIndex
	end

	RefreshAllSlots()
end

local function HandleHotbarUpdate(HotbarData: { [number]: any })
	table.clear(HotbarItems)

	for SlotIndex, ItemData in HotbarData do
		if typeof(ItemData) == "table" and ItemData.ToolId then
			HotbarItems[SlotIndex] = {
				ToolId = ItemData.ToolId,
				ToolName = ItemData.ToolName or "Unknown",
				Icon = ItemData.Icon or "",
			}
		end
	end

	RefreshAllSlots()
end

local function HandleEquippedToolUpdate(SlotIndex: number?)
	EquippedSlot = SlotIndex
	RefreshAllSlots()
end

local function ConnectInput(): ()
	UserInputService.InputBegan:Connect(function(InputObject: InputObject, WasProcessed: boolean)
		if WasProcessed then
			return
		end

		local SlotIndex: number? = KEYCODE_TO_SLOT[InputObject.KeyCode]
		if SlotIndex == nil then
			return
		end

		EquipToolAtSlot(SlotIndex)
	end)
end

local function OnCharacterAdded(_NewCharacter: Model): ()
	table.clear(HotbarItems)
	EquippedSlot = nil

	RefreshAllSlots()

	Packets.RequestHotbarSync:Fire()
end

local function BuildGui(): ()
	local CreatedGui: ScreenGui = Instance.new("ScreenGui")
	CreatedGui.Name = "HotbarGui"
	CreatedGui.ResetOnSpawn = false
	CreatedGui.IgnoreGuiInset = true
	CreatedGui.Parent = PlayerGui
	HotbarGui = CreatedGui

	local CreatedRoot: Frame = Instance.new("Frame")
	CreatedRoot.Name = "RootFrame"
	CreatedRoot.AnchorPoint = Vector2.new(0.5, 1)
	CreatedRoot.Position = UDim2.fromScale(0.5, 1)
	CreatedRoot.Size = UDim2.new(0, 0, 0, 0)
	CreatedRoot.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	CreatedRoot.BorderSizePixel = 0
	CreatedRoot.Visible = false
	CreatedRoot.Parent = HotbarGui
	RootFrame = CreatedRoot

	local RootPadding: UIPadding = Instance.new("UIPadding")
	RootPadding.PaddingBottom = UDim.new(0, HOTBAR_BOTTOM_MARGIN)
	RootPadding.PaddingLeft = UDim.new(0, SLOT_PADDING)
	RootPadding.PaddingRight = UDim.new(0, SLOT_PADDING)
	RootPadding.PaddingTop = UDim.new(0, SLOT_PADDING)
	RootPadding.Parent = CreatedRoot

	local CreatedSlotsFrame: Frame = Instance.new("Frame")
	CreatedSlotsFrame.Name = "SlotsFrame"
	CreatedSlotsFrame.BackgroundTransparency = 1
	CreatedSlotsFrame.BorderSizePixel = 0
	CreatedSlotsFrame.Size = UDim2.fromScale(1, 1)
	CreatedSlotsFrame.Parent = CreatedRoot
	SlotsFrame = CreatedSlotsFrame

	local Layout: UIListLayout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center
	Layout.Padding = UDim.new(0, SLOT_PADDING)
	Layout.Parent = SlotsFrame

	for SlotIndex: number = 1, MAX_SLOTS do
		local SlotFrame: Frame = Instance.new("Frame")
		SlotFrame.Name = "Slot" .. tostring(SlotIndex)
		SlotFrame.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
		SlotFrame.BackgroundColor3 = SLOT_BACKGROUND_COLOR
		SlotFrame.BackgroundTransparency = SLOT_BACKGROUND_TRANSPARENCY
		SlotFrame.BorderSizePixel = 0
		SlotFrame.Visible = false
		SlotFrame.Parent = CreatedSlotsFrame

		local IconImage: ImageLabel = Instance.new("ImageLabel")
		IconImage.Name = "Icon"
		IconImage.BackgroundTransparency = 1
		IconImage.BorderSizePixel = 0
		IconImage.Size = UDim2.fromScale(1, 1)
		IconImage.Image = ""
		IconImage.ScaleType = Enum.ScaleType.Fit
		IconImage.Parent = SlotFrame

		local KeyLabel: TextLabel = Instance.new("TextLabel")
		KeyLabel.Name = "KeyLabel"
		KeyLabel.BackgroundTransparency = 1
		KeyLabel.BorderSizePixel = 0
		KeyLabel.Position = UDim2.fromOffset(6, 4)
		KeyLabel.Size = UDim2.fromOffset(14, 14)
		KeyLabel.Text = tostring(SlotIndex % 10)
		KeyLabel.TextColor3 = SLOT_TEXT_COLOR
		KeyLabel.TextScaled = true
		KeyLabel.Font = Enum.Font.GothamBold
		KeyLabel.Parent = SlotFrame

		local NameLabel: TextLabel = Instance.new("TextLabel")
		NameLabel.Name = "NameLabel"
		NameLabel.BackgroundTransparency = 1
		NameLabel.BorderSizePixel = 0
		NameLabel.AnchorPoint = Vector2.new(0.5, 1)
		NameLabel.Position = UDim2.new(0.5, 0, 1, -4)
		NameLabel.Size = UDim2.new(1, -8, 0, 34)
		NameLabel.Text = ""
		NameLabel.TextColor3 = SLOT_TEXT_COLOR
		NameLabel.TextScaled = true
		NameLabel.Font = Enum.Font.Gotham
		NameLabel.TextYAlignment = Enum.TextYAlignment.Center
		NameLabel.TextXAlignment = Enum.TextXAlignment.Center
		NameLabel.Parent = SlotFrame

		local CooldownOverlay: Frame = Instance.new("Frame")
		CooldownOverlay.Name = "CooldownOverlay"
		CooldownOverlay.BackgroundTransparency = 0.5
		CooldownOverlay.BorderSizePixel = 0
		CooldownOverlay.Size = UDim2.fromScale(1, 1)
		CooldownOverlay.Visible = false
		CooldownOverlay.Parent = SlotFrame

		local ClickButton: TextButton = Instance.new("TextButton")
		ClickButton.Name = "ClickButton"
		ClickButton.BackgroundTransparency = 1
		ClickButton.BorderSizePixel = 0
		ClickButton.Size = UDim2.fromScale(1, 1)
		ClickButton.Text = ""
		ClickButton.Parent = SlotFrame

		local UIStroke: UIStroke = Instance.new("UIStroke")
		UIStroke.Thickness = 0
		UIStroke.Transparency = UISTROKE_TRANSPARENCY
		UIStroke.Color = UISTROKE_COLOR
		UIStroke.Parent = SlotFrame

		ClickButton.Activated:Connect(function()
			EquipToolAtSlot(SlotIndex)
		end)

		SlotUis[SlotIndex] = {
			SlotFrame = SlotFrame,
			IconImage = IconImage,
			NameLabel = NameLabel,
			KeyLabel = KeyLabel,
			CooldownOverlay = CooldownOverlay,
		}
	end
end

local function Initialize(): ()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	BuildGui()
	ConnectInput()

	Packets.HotbarUpdate.OnClientEvent:Connect(HandleHotbarUpdate)
	Packets.EquippedToolUpdate.OnClientEvent:Connect(HandleEquippedToolUpdate)

	LOCAL_PLAYER.CharacterAdded:Connect(OnCharacterAdded)

	local ExistingCharacter: Model? = LOCAL_PLAYER.Character
	if ExistingCharacter ~= nil then
		OnCharacterAdded(ExistingCharacter)
	end
end

Initialize()
