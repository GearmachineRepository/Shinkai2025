--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local Types = require(Server.Ensemble.Types)

local ToolComponent = {}
ToolComponent.__index = ToolComponent

ToolComponent.ComponentName = "Tool"
ToolComponent.Dependencies = { "Inventory" }

type Self = {
	Entity: Types.Entity,
	Character: Model,
	Player: Player,
	EquippedTool: { ToolId: string, SlotIndex: number }?,
}

function ToolComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local ToolComponentInstance: Self = setmetatable({
		Entity = Entity,
		Character = Entity.Character,
		Player = Entity.Player :: Player,
		EquippedTool = nil,
	}, ToolComponent) :: any

	return ToolComponentInstance
end

function ToolComponent.EquipTool(self: Self, SlotIndex: number): boolean
	local Inventory = self.Entity:GetComponent("Inventory") :: any
	if not Inventory then
		return false
	end

	local ItemInSlot = Inventory:GetItemInSlot(SlotIndex)
	if not ItemInSlot then
		return false
	end

	if self.EquippedTool then
		if self.EquippedTool.SlotIndex == SlotIndex then
			ToolComponent.UnequipTool(self)
			return true
		end

		ToolComponent.UnequipTool(self)
	end

	self.EquippedTool = {
		ToolId = ItemInSlot.Id,
		SlotIndex = SlotIndex,
	}

	self.Character:SetAttribute("EquippedToolId", ItemInSlot.ToolId)
	self.Character:SetAttribute("EquippedToolSlot", SlotIndex)
	self.Character:SetAttribute("EquippedItemId", ItemInSlot.Id)

	return true
end

function ToolComponent.UnequipTool(self: Self)
	if not self.EquippedTool then
		return
	end

	self.EquippedTool = nil
	self.Character:SetAttribute("EquippedToolId", nil)
	self.Character:SetAttribute("EquippedToolSlot", nil)
	self.Character:SetAttribute("EquippedItemId", nil)
end

function ToolComponent.GetEquippedTool(self: Self): { ToolId: string, SlotIndex: number }?
	return self.EquippedTool
end

function ToolComponent.IsToolEquipped(self: Self, SlotIndex: number): boolean
	if not self.EquippedTool then
		return false
	end

	return self.EquippedTool.SlotIndex == SlotIndex
end

function ToolComponent.Destroy(self: Self)
	ToolComponent.UnequipTool(self)
end

return ToolComponent
