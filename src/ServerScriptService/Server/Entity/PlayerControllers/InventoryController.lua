--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local ItemInstance = require(Shared.Configurations.Data.ItemInstance)
local Packets = require(Shared.Networking.Packets)
local DebugLogger = require(Shared.Debug.DebugLogger)

local InventoryController = {}
InventoryController.__index = InventoryController

export type InventoryController = typeof(setmetatable(
	{} :: {
		Character: Model,
		Player: Player,
		PlayerData: any,
		HotbarSlots: { [number]: any? },
		BackpackItems: { any },
	},
	InventoryController
))

local MAX_HOTBAR_SLOTS = 10

function InventoryController.new(CharacterController: any, PlayerData: any): InventoryController
	local self = setmetatable({
		Character = CharacterController.Character,
		Player = CharacterController.Player,
		PlayerData = PlayerData,
		HotbarSlots = {},
		BackpackItems = {},
	}, InventoryController)

	self:LoadInventoryFromData()

	return self
end

function InventoryController:LoadInventoryFromData()
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

function InventoryController:GetItemInSlot(SlotIndex: number): any?
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return nil
	end

	return self.HotbarSlots[SlotIndex]
end

function InventoryController:AddItemToHotbar(SlotIndex: number, ItemId: string, Quantity: number?): boolean
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		DebugLogger.Warning("InventoryController", "Invalid slot index: %d", SlotIndex)
		return false
	end

	if not ItemDatabase.ItemExists(ItemId) then
		DebugLogger.Warning("InventoryController", "Invalid ItemId: %s", ItemId)
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

function InventoryController:AddItemInstanceToHotbar(SlotIndex: number, Instance: any): boolean
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return false
	end

	self.HotbarSlots[SlotIndex] = Instance
	self:SaveToPlayerData()
	self:SendHotbarUpdate()
	return true
end

function InventoryController:RemoveItemFromHotbar(SlotIndex: number): boolean
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return false
	end

	self.HotbarSlots[SlotIndex] = nil
	self:SaveToPlayerData()
	self:SendHotbarUpdate()
	return true
end

function InventoryController:AddItemToBackpack(ItemId: string, Quantity: number?): boolean
	if not ItemDatabase.ItemExists(ItemId) then
		return false
	end

	local Instance = ItemInstance.Create(ItemId, Quantity)
	if not Instance then
		return false
	end

	table.insert(self.BackpackItems, Instance)
	self:SaveToPlayerData()
	return true
end

function InventoryController:AddItemInstanceToBackpack(Instance: any)
	table.insert(self.BackpackItems, Instance)
	self:SaveToPlayerData()
end

function InventoryController:SendHotbarUpdate()
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

function InventoryController:SaveToPlayerData()
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

function InventoryController:GetItemInstance(SlotIndex: number): any?
	return self:GetItemInSlot(SlotIndex)
end

function InventoryController:DamageItemDurability(SlotIndex: number, Amount: number): boolean
	local Instance = self:GetItemInSlot(SlotIndex)
	if not Instance then
		return false
	end

	local IsStillUsable = ItemInstance.DamageDurability(Instance, Amount)

	if not IsStillUsable then
		self:RemoveItemFromHotbar(SlotIndex)
		DebugLogger.Info("InventoryController", "Item broke in slot %d for %s", SlotIndex, self.Player.Name)
	else
		self:SaveToPlayerData()
		self:SendHotbarUpdate()
	end

	return IsStillUsable
end

function InventoryController:ModifyItemStat(SlotIndex: number, StatName: string, Delta: number)
	local Instance = self:GetItemInSlot(SlotIndex)
	if not Instance then
		return
	end

	ItemInstance.ModifyStat(Instance, StatName, Delta)
	self:SaveToPlayerData()
	self:SendHotbarUpdate()
end

function InventoryController:SetItemStat(SlotIndex: number, StatName: string, Value: number)
	local Instance = self:GetItemInSlot(SlotIndex)
	if not Instance then
		return
	end

	ItemInstance.SetStat(Instance, StatName, Value)
	self:SaveToPlayerData()
	self:SendHotbarUpdate()
end

function InventoryController:GetItemStat(SlotIndex: number, StatName: string): number?
	local Instance = self:GetItemInSlot(SlotIndex)
	if not Instance then
		return nil
	end

	return ItemInstance.GetStat(Instance, StatName)
end

function InventoryController:Destroy()
	table.clear(self.HotbarSlots)
	table.clear(self.BackpackItems)
end

return InventoryController
