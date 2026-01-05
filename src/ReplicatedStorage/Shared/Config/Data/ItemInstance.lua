--!strict
local ItemDatabase = require(script.Parent.ItemDatabase)

local ItemInstance = {}

export type ItemStats = {
	Damage: number?,
	AttackSpeed: number?,
	Range: number?,
	Durability: number?,
	Defense: number?,
	Power: number?,
	Speed: number?,
	Cooldown: number?,
}

export type ItemInstance = {
	Id: string,
	Quantity: number,
	Info: ItemStats,
}

function ItemInstance.Create(ItemId: string, Quantity: number?): ItemInstance?
	local ItemDef = ItemDatabase.GetItem(ItemId)
	if not ItemDef then
		warn("ItemInstance: Invalid ItemId:", ItemId)
		return nil
	end

	local FinalQuantity = Quantity or 1
	if FinalQuantity > ItemDef.MaxStackSize then
		FinalQuantity = ItemDef.MaxStackSize
	end

	local Instance: ItemInstance = {
		Id = ItemId,
		Quantity = FinalQuantity,
		Info = {},
	}

	if ItemDef.Metadata then
		Instance.Info = {}
		for StatName, StatValue in ItemDef.Metadata do
			Instance.Info[StatName] = StatValue
		end
	end

	return Instance
end

function ItemInstance.FromData(Data: any): ItemInstance?
	if typeof(Data) ~= "table" then
		return nil
	end

	if not Data.Id then
		return nil
	end

	local ItemDef = ItemDatabase.GetItem(Data.Id)
	if not ItemDef then
		warn("ItemInstance: Invalid ItemId in data:", Data.Id)
		return nil
	end

	local Instance: ItemInstance = {
		Id = Data.Id,
		Quantity = Data.Quantity or 1,
		Info = {},
	}

	if Data.Info then
		Instance.Info = {}
		for StatName, StatValue in pairs(Data.Info) do
			Instance.Info[StatName] = StatValue
		end
	end

	return Instance
end

function ItemInstance.ToData(Instance: ItemInstance): any
	local Data = {
		Id = Instance.Id,
		Quantity = Instance.Quantity,
	}

	if Instance.Info then
		Data.Info = {}
		for StatName, StatValue in Instance.Info do
			Data.Info[StatName] = StatValue
		end
	end

	return Data
end

function ItemInstance.GetDefinition(Instance: ItemInstance)
	return ItemDatabase.GetItem(Instance.Id)
end

function ItemInstance.GetStat(Instance: ItemInstance, StatName: string): number?
	if Instance.Info and Instance.Info[StatName] ~= nil then
		return Instance.Info[StatName]
	end

	local ItemDef = ItemDatabase.GetItem(Instance.Id)
	if not ItemDef or not ItemDef.Metadata then
		return nil
	end

	return ItemDef.Metadata[StatName]
end

function ItemInstance.SetStat(Instance: ItemInstance, StatName: string, Value: number)
	if not Instance.Info then
		Instance.Info = {}
	end

	Instance.Info[StatName] = Value
end

function ItemInstance.ModifyStat(Instance: ItemInstance, StatName: string, Delta: number)
	local CurrentValue = ItemInstance.GetStat(Instance, StatName) or 0
	ItemInstance.SetStat(Instance, StatName, CurrentValue + Delta)
end

function ItemInstance.DamageDurability(Instance: ItemInstance, Amount: number): boolean
	local CurrentDurability = ItemInstance.GetStat(Instance, "Durability")
	if not CurrentDurability then
		return true
	end

	local NewDurability = math.max(0, CurrentDurability - Amount)
	ItemInstance.SetStat(Instance, "Durability", NewDurability)

	return NewDurability > 0
end

function ItemInstance.RepairDurability(Instance: ItemInstance, Amount: number)
	local CurrentDurability = ItemInstance.GetStat(Instance, "Durability")
	if not CurrentDurability then
		return
	end

	local ItemDef = ItemDatabase.GetItem(Instance.Id)
	if not ItemDef or not ItemDef.Metadata or not ItemDef.Metadata.Durability then
		return
	end

	local MaxDurability = ItemDef.Metadata.Durability
	local NewDurability = math.min(MaxDurability, CurrentDurability + Amount)
	ItemInstance.SetStat(Instance, "Durability", NewDurability)
end

function ItemInstance.GetMaxDurability(Instance: ItemInstance): number?
	local ItemDef = ItemDatabase.GetItem(Instance.Id)
	if not ItemDef or not ItemDef.Metadata then
		return nil
	end

	return ItemDef.Metadata.Durability
end

function ItemInstance.CanStack(Instance1: ItemInstance, Instance2: ItemInstance): boolean
	if Instance1.Id ~= Instance2.Id then
		return false
	end

	if Instance1.Info or Instance2.Info then
		return false
	end

	return true
end

function ItemInstance.Stack(Instance1: ItemInstance, Instance2: ItemInstance): boolean
	if not ItemInstance.CanStack(Instance1, Instance2) then
		return false
	end

	local ItemDef = ItemDatabase.GetItem(Instance1.Id)
	if not ItemDef then
		return false
	end

	local TotalQuantity = Instance1.Quantity + Instance2.Quantity

	if TotalQuantity > ItemDef.MaxStackSize then
		return false
	end

	Instance1.Quantity = TotalQuantity
	return true
end

return ItemInstance
