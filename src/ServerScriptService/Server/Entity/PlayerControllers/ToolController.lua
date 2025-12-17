--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local DebugLogger = require(Shared.Debug.DebugLogger)

local ToolController = {}
ToolController.__index = ToolController

export type ToolController = typeof(setmetatable(
	{} :: {
		Character: Model,
		Player: Player,
		InventoryController: any,
		EquippedTool: { ToolId: string, SlotIndex: number }?,
	},
	ToolController
))

function ToolController.new(CharacterController: any): ToolController
	local self = setmetatable({
		Character = CharacterController.Character,
		Player = CharacterController.Player,
		InventoryController = CharacterController.InventoryController,
		EquippedTool = nil,
	}, ToolController)

	return self
end

function ToolController:EquipTool(SlotIndex: number): boolean
	if not self.InventoryController then
		DebugLogger.Warning("ToolController", "No InventoryController for %s", self.Player.Name)
		return false
	end

	local ItemInSlot = self.InventoryController:GetItemInSlot(SlotIndex)
	if not ItemInSlot then
		DebugLogger.Info("ToolController", "No item in slot %d for %s", SlotIndex, self.Player.Name)
		return false
	end

	if self.EquippedTool then
		if self.EquippedTool.SlotIndex == SlotIndex then
			self:UnequipTool()
			return true
		end

		self:UnequipTool()
	end

	self.EquippedTool = {
		ToolId = ItemInSlot.ToolId,
		SlotIndex = SlotIndex,
	}

	self.Character:SetAttribute("EquippedToolId", ItemInSlot.ToolId)
	self.Character:SetAttribute("EquippedToolSlot", SlotIndex)

	DebugLogger.Info(
		"ToolController",
		"%s equipped tool %s from slot %d",
		self.Player.Name,
		ItemInSlot.ToolName,
		SlotIndex
	)

	return true
end

function ToolController:UnequipTool()
	if not self.EquippedTool then
		return
	end

	local PreviousSlot = self.EquippedTool.SlotIndex

	self.EquippedTool = nil
	self.Character:SetAttribute("EquippedToolId", nil)
	self.Character:SetAttribute("EquippedToolSlot", nil)

	DebugLogger.Info("ToolController", "%s unequipped tool from slot %d", self.Player.Name, PreviousSlot)
end

function ToolController:GetEquippedTool(): { ToolId: string, SlotIndex: number }?
	return self.EquippedTool
end

function ToolController:IsToolEquipped(SlotIndex: number): boolean
	if not self.EquippedTool then
		return false
	end

	return self.EquippedTool.SlotIndex == SlotIndex
end

function ToolController:Destroy()
	self:UnequipTool()
end

return ToolController
