--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Types = require(Server.Ensemble.Types)

local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local ItemInstance = require(Shared.Configurations.Data.ItemInstance)
local Packets = require(Shared.Networking.Packets)

local InventoryComponent = {}
InventoryComponent.__index = InventoryComponent

InventoryComponent.ComponentName = "Inventory"
InventoryComponent.Dependencies = {}

local MAX_HOTBAR_SLOTS = 10

type Self = {
	Entity: Types.Entity,
	Player: Player,
	PlayerData: any,
	HotbarSlots: { [number]: any? },
	BackpackItems: { any },
}

function InventoryComponent.new(Entity: Types.Entity, Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Player = Entity.Player :: Player,
		PlayerData = Context.Data,
		HotbarSlots = {},
		BackpackItems = {},
	}, InventoryComponent) :: any

	InventoryComponent.LoadInventoryFromData(self)

	return self
end

function InventoryComponent.LoadInventoryFromData(self: Self)
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

function InventoryComponent.GetItemInSlot(self: Self, SlotIndex: number): any?
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return nil
	end

	return self.HotbarSlots[SlotIndex]
end

function InventoryComponent.AddItemToHotbar(self: Self, SlotIndex: number, ItemId: string, Quantity: number?): boolean
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
	InventoryComponent.SaveToPlayerData(self)
	InventoryComponent.SendHotbarUpdate(self)
	return true
end

function InventoryComponent.RemoveItemFromHotbar(self: Self, SlotIndex: number): boolean
	if SlotIndex < 1 or SlotIndex > MAX_HOTBAR_SLOTS then
		return false
	end

	self.HotbarSlots[SlotIndex] = nil
	InventoryComponent.SaveToPlayerData(self)
	InventoryComponent.SendHotbarUpdate(self)
	return true
end

function InventoryComponent.SendHotbarUpdate(self: Self)
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

function InventoryComponent.SaveToPlayerData(self: Self)
	if not self.PlayerData then
		return
	end

	self.PlayerData.Hotbar = {}
	for SlotIndex, Instance: any in pairs(self.HotbarSlots) do
		self.PlayerData.Hotbar[SlotIndex] = ItemInstance.ToData(Instance)
	end

	self.PlayerData.Backpack = {}
	for _, Instance in pairs(self.BackpackItems) do
		table.insert(self.PlayerData.Backpack, ItemInstance.ToData(Instance))
	end
end

function InventoryComponent.Destroy(self: Self)
	table.clear(self.HotbarSlots)
	table.clear(self.BackpackItems)
end

return InventoryComponent