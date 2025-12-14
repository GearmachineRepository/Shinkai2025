--!strict

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local LOCAL_PLAYER: Player = Players.LocalPlayer
local PlayerGui: PlayerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

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

local HotbarGui: ScreenGui? = nil
local RootFrame: Frame? = nil
local SlotsFrame: Frame? = nil
local SlotUis: { SlotUi } = {}

local Character: Model? = nil
local Humanoid: Humanoid? = nil

local SlotIndexToTool: { [number]: Tool } = {}
local ToolToSlotIndex: { [Tool]: number } = {}

local EquippedTool: Tool? = nil

local function IsTool(InstanceValue: Instance): boolean
	return InstanceValue:IsA("Tool")
end

local function GetBackpack(): Backpack
	return LOCAL_PLAYER.Backpack
end

local function GetToolIcon(ToolInstance: Tool): string
	if ToolInstance.TextureId ~= "" then
		return ToolInstance.TextureId
	end

	local IconAttribute: any = ToolInstance:GetAttribute("Icon")
	if typeof(IconAttribute) == "string" then
		return IconAttribute
	end

	return ""
end

local function IsToolOwnedByPlayer(ToolInstance: Tool): boolean
	local CurrentCharacter: Model? = LOCAL_PLAYER.Character
	local CurrentBackpack: Backpack = GetBackpack()

	if ToolInstance.Parent == CurrentBackpack then
		return true
	end

	if CurrentCharacter ~= nil and ToolInstance.Parent == CurrentCharacter then
		return true
	end

	return false
end

local function FindFirstEmptySlot(): number?
	for SlotIndex: number = 1, MAX_SLOTS do
		if SlotIndexToTool[SlotIndex] == nil then
			return SlotIndex
		end
	end
	return nil
end

local function GetVisibleSlotCount(): number
	local Count: number = 0
	for SlotIndex: number = 1, MAX_SLOTS do
		if SlotIndexToTool[SlotIndex] ~= nil then
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

local function SetSlotVisual(SlotIndex: number, ToolInstance: Tool?): ()
	local SlotUiValue: SlotUi? = SlotUis[SlotIndex]
	if SlotUiValue == nil then
		return
	end

	if ToolInstance == nil then
		SlotUiValue.IconImage.Image = ""
		SlotUiValue.NameLabel.Text = ""
		SlotUiValue.CooldownOverlay.Visible = false
		SlotUiValue.SlotFrame.Visible = false
		SlotUiValue.SlotFrame.BackgroundTransparency = SLOT_BACKGROUND_TRANSPARENCY
		return
	end

	SlotUiValue.SlotFrame.Visible = true
	SlotUiValue.IconImage.Image = GetToolIcon(ToolInstance)
	SlotUiValue.NameLabel.Text = ToolInstance.Name
	SlotUiValue.CooldownOverlay.Visible = false

	if EquippedTool == ToolInstance then
		SlotUiValue.SlotFrame.BackgroundTransparency = EQUIPPED_BACKGROUND_TRANSPARENCY
		SlotUiValue.SlotFrame.BackgroundColor3 = EQUIPPED_BACKGROUND_COLOR
		SlotUiValue.SlotFrame.UIStroke.Thickness = 1
	else
		SlotUiValue.SlotFrame.BackgroundTransparency = SLOT_BACKGROUND_TRANSPARENCY
		SlotUiValue.SlotFrame.UIStroke.Thickness = 0
	end
end

local function RefreshAllSlots(): ()
	for SlotIndex: number = 1, MAX_SLOTS do
		SetSlotVisual(SlotIndex, SlotIndexToTool[SlotIndex])
	end
	ApplyLayoutVisibility()
end

local function RegisterTool(ToolInstance: Tool): ()
	if ToolToSlotIndex[ToolInstance] ~= nil then
		return
	end

	if not IsToolOwnedByPlayer(ToolInstance) then
		return
	end

	local SlotIndex: number? = FindFirstEmptySlot()
	if SlotIndex == nil then
		return
	end

	SlotIndexToTool[SlotIndex] = ToolInstance
	ToolToSlotIndex[ToolInstance] = SlotIndex

	RefreshAllSlots()
end

local function UnregisterTool(ToolInstance: Tool): ()
	local SlotIndex: number? = ToolToSlotIndex[ToolInstance]
	if SlotIndex == nil then
		return
	end

	if EquippedTool == ToolInstance then
		EquippedTool = nil
	end

	ToolToSlotIndex[ToolInstance] = nil
	SlotIndexToTool[SlotIndex] = nil

	RefreshAllSlots()
end

local function SafeUnregisterIfTrulyGone(ToolInstance: Tool): ()
	task.defer(function()
		if not IsToolOwnedByPlayer(ToolInstance) then
			UnregisterTool(ToolInstance)
		else
			RefreshAllSlots()
		end
	end)
end

local function EquipToolAtSlot(SlotIndex: number): ()
	local ToolInstance: Tool? = SlotIndexToTool[SlotIndex]
	if ToolInstance == nil then
		return
	end

	local CurrentHumanoid: Humanoid? = Humanoid
	if CurrentHumanoid == nil then
		return
	end

	if EquippedTool == ToolInstance then
		CurrentHumanoid:UnequipTools()
		EquippedTool = nil
		RefreshAllSlots()
		return
	end

	CurrentHumanoid:EquipTool(ToolInstance)
	EquippedTool = ToolInstance
	RefreshAllSlots()
end

local function ScanForTools(Container: Instance): ()
	for _, Descendant: Instance in Container:GetDescendants() do
		if IsTool(Descendant) then
			RegisterTool(Descendant :: Tool)
		end
	end

	for _, Child: Instance in Container:GetChildren() do
		if IsTool(Child) then
			RegisterTool(Child :: Tool)
		end
	end
end

local function ClearAllTools(): ()
	for SlotIndex: number = 1, MAX_SLOTS do
		SlotIndexToTool[SlotIndex] = nil
	end

	for ToolInstance: Tool, _ in pairs(ToolToSlotIndex) do
		ToolToSlotIndex[ToolInstance] = nil
	end

	EquippedTool = nil
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

local function BindBackpackSignals(BackpackInstance: Backpack): ()
	BackpackInstance.DescendantAdded:Connect(function(Descendant: Instance)
		if IsTool(Descendant) then
			RegisterTool(Descendant :: Tool)
		end
	end)

	BackpackInstance.DescendantRemoving:Connect(function(Descendant: Instance)
		if IsTool(Descendant) then
			SafeUnregisterIfTrulyGone(Descendant :: Tool)
		end
	end)
end

local function BindCharacterSignals(CharacterModel: Model): ()
	CharacterModel.DescendantAdded:Connect(function(Descendant: Instance)
		if IsTool(Descendant) then
			RegisterTool(Descendant :: Tool)
		end
	end)

	CharacterModel.DescendantRemoving:Connect(function(Descendant: Instance)
		if IsTool(Descendant) then
			SafeUnregisterIfTrulyGone(Descendant :: Tool)
		end
	end)
end

local function OnCharacterAdded(NewCharacter: Model): ()
	Character = NewCharacter
	Humanoid = NewCharacter:WaitForChild("Humanoid") :: Humanoid

	ClearAllTools()

	BindCharacterSignals(Character)

	local CurrentBackpack: Backpack = GetBackpack()
	ScanForTools(CurrentBackpack)
	ScanForTools(Character)

	RefreshAllSlots()
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
		KeyLabel.Text = tostring(SlotIndex)
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

	local CurrentBackpack: Backpack = GetBackpack()
	BindBackpackSignals(CurrentBackpack)

	LOCAL_PLAYER.CharacterAdded:Connect(OnCharacterAdded)

	local ExistingCharacter: Model? = LOCAL_PLAYER.Character
	if ExistingCharacter ~= nil then
		OnCharacterAdded(ExistingCharacter)
	else
		ClearAllTools()
		ScanForTools(CurrentBackpack)
		RefreshAllSlots()
	end
end

Initialize()
