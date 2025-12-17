--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local ItemInstance = require(Shared.Configurations.Data.ItemInstance)
local Packets = require(Shared.Networking.Packets)

export type InventoryComponent = {
	Entity: any,
	GetItemInSlot: (self: InventoryComponent, SlotIndex: number) -> any?,
	AddItemToHotbar: (self: InventoryComponent, SlotIndex: number, ItemId: string, Quantity: number?) -> boolean,
	RemoveItemFromHotbar: (self: InventoryComponent, SlotIndex: number) -> boolean,
	SendHotbarUpdate: (self: InventoryComponent) -> (),
	Destroy: (self: InventoryComponent) -> (),
}

type InventoryComponentInternal = InventoryComponent & {
	Player: Player,
	PlayerData: any,
	HotbarSlots: { [number]: any? },
	BackpackItems: { any },
}

local InventoryComponent = {}
InventoryComponent.__index = InventoryComponent

local MAX_HOTBAR_SLOTS = 10

function InventoryComponent.new(Entity: any, PlayerData: any): InventoryComponent
	local self: InventoryComponentInternal = setmetatable({
		Entity = Entity,
		Player = Entity.Player,
		PlayerData = PlayerData,
		HotbarSlots = {},
		BackpackItems = {},
	}, InventoryComponent) :: any

	self:LoadInventoryFromData()

	return self
end

function InventoryComponent:LoadInventoryFromData()
	if not self.PlayerData then
		return
	end

	if self.PlayerData.Hotbar then
		for SlotIndex = 1, MAX_HOTBAR_SLOTS do
			local SlotData = self.PlayerData.Hotbar[SlotIndex]
			if SlotData then
				local Instance = ItemInstance.FromData(SlotData)
				if Instance then
					self.HotbarSlots[SlotIndex] = Instance
				end
			end
		end
	end

	if self.PlayerData.Backpack then
		for _, ItemData in self.PlayerData.Backpack do
			local Instance = ItemInstance.FromData(ItemData)
			if Instance then
				table.insert(self.BackpackItems, Instance)
			end
		end
	end
end

function InventoryComponent:GetItemInSlot(SlotIndex: number): any?
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return nil
	end

	return self.HotbarSlots[SlotIndex]
end

function InventoryComponent:AddItemToHotbar(SlotIndex: number, ItemId: string, Quantity: number?): boolean
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return false
	end

	if not ItemDatabase.ItemExists(ItemId) then
		return false
	end

	local Instance = ItemInstance.Create(ItemId, Quantity)
	if not Instance then
		return false
	end

	self.HotbarSlots[SlotIndex] = Instance
	self:SaveToPlayerData()
	self:SendHotbarUpdate()
	return true
end

function InventoryComponent:RemoveItemFromHotbar(SlotIndex: number): boolean
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return false
	end

	self.HotbarSlots[SlotIndex] = nil
	self:SaveToPlayerData()
	self:SendHotbarUpdate()
	return true
end

function InventoryComponent:SendHotbarUpdate()
	local HotbarData: { [number]: any } = {}

	for SlotIndex = 1, MAX_HOTBAR_SLOTS do
		local Instance = self.HotbarSlots[SlotIndex]
		if Instance then
			local ItemDef = ItemInstance.GetDefinition(Instance)
			if ItemDef then
				local Durability = ItemInstance.GetStat(Instance, "Durability")
				local MaxDurability = ItemInstance.GetMaxDurability(Instance)

				HotbarData[SlotIndex] = {
					ToolId = Instance.Id,
					ToolName = ItemDef.ItemName,
					Icon = ItemDef.Icon,
					Quantity = Instance.Quantity,
					Durability = Durability,
					MaxDurability = MaxDurability,
				}
			end
		end
	end

	Packets.HotbarUpdate:FireClient(self.Player, HotbarData)
end

function InventoryComponent:SaveToPlayerData()
	if not self.PlayerData then
		return
	end

	self.PlayerData.Hotbar = {}
	for SlotIndex, Instance in self.HotbarSlots do
		self.PlayerData.Hotbar[SlotIndex] = ItemInstance.ToData(Instance)
	end

	self.PlayerData.Backpack = {}
	for _, Instance in self.BackpackItems do
		table.insert(self.PlayerData.Backpack, ItemInstance.ToData(Instance))
	end
end

function InventoryComponent:Destroy()
	table.clear(self.HotbarSlots)
	table.clear(self.BackpackItems)
end

return InventoryComponent
