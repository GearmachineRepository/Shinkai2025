--!strict

export type ToolComponent = {
	Entity: any,
	EquipTool: (self: ToolComponent, SlotIndex: number) -> boolean,
	UnequipTool: (self: ToolComponent) -> (),
	GetEquippedTool: (self: ToolComponent) -> { ToolId: string, SlotIndex: number }?,
	IsToolEquipped: (self: ToolComponent, SlotIndex: number) -> boolean,
	Destroy: (self: ToolComponent) -> (),
}

type ToolComponentInternal = ToolComponent & {
	Character: Model,
	Player: Player,
	EquippedTool: { ToolId: string, SlotIndex: number }?,
}

local ToolComponent = {}
ToolComponent.__index = ToolComponent

function ToolComponent.new(Entity: any): ToolComponent
	local self: ToolComponentInternal = setmetatable({
		Entity = Entity,
		Character = Entity.Character,
		Player = Entity.Player,
		EquippedTool = nil,
	}, ToolComponent) :: any

	return self
end

function ToolComponent:EquipTool(SlotIndex: number): boolean
	if not self.Entity.Components.Inventory then
		return false
	end

	local ItemInSlot = self.Entity.Components.Inventory:GetItemInSlot(SlotIndex)
	if not ItemInSlot then
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

	return true
end

function ToolComponent:UnequipTool()
	if not self.EquippedTool then
		return
	end

	self.EquippedTool = nil
	self.Character:SetAttribute("EquippedToolId", nil)
	self.Character:SetAttribute("EquippedToolSlot", nil)
end

function ToolComponent:GetEquippedTool(): { ToolId: string, SlotIndex: number }?
	return self.EquippedTool
end

function ToolComponent:IsToolEquipped(SlotIndex: number): boolean
	if not self.EquippedTool then
		return false
	end

	return self.EquippedTool.SlotIndex == SlotIndex
end

function ToolComponent:Destroy()
	self:UnequipTool()
end

return ToolComponent
