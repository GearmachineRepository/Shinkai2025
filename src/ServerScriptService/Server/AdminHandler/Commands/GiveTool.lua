--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterController = require(Server.Entity.Core.CharacterController)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)

return {
	Description = "Give yourself a tool from the ItemDatabase",
	Usage = "!givetool [slot] [item_id] [quantity]",
	Execute = function(Player: Player, SlotStr: string?, ItemId: string?, QuantityStr: string?)
		local Character = CommandUtil.GetCharacter(Player)
		if not Character then
			warn("No character found")
			return
		end

		local SlotIndex = tonumber(SlotStr) or 1
		local FinalItemId = ItemId or "wooden_sword"
		local Quantity = tonumber(QuantityStr) or 1

		if SlotIndex < 1 or SlotIndex > 10 then
			warn("Slot must be between 1 and 10")
			return
		end

		if not ItemDatabase.ItemExists(FinalItemId) then
			warn("Invalid ItemId:", FinalItemId)
			print("Available items:")
			for _, ItemDef in ItemDatabase.GetAllItems() do
				print("  -", ItemDef.ItemId, "-", ItemDef.ItemName)
			end
			return
		end

		local Controller = CharacterController.Get(Character)
		if not Controller then
			warn("No controller found for", Character.Name)
			return
		end

		if not Controller.InventoryController then
			warn("No InventoryController for", Character.Name)
			return
		end

		local Success = Controller.InventoryController:AddItemToHotbar(SlotIndex, FinalItemId, Quantity)

		if Success then
			local ItemDef = ItemDatabase.GetItem(FinalItemId)
			print(string.format("Gave %s '%s' x%d in slot %d", Player.Name, ItemDef.ItemName, Quantity, SlotIndex))
		else
			warn("Failed to add item to hotbar")
		end
	end,
}
