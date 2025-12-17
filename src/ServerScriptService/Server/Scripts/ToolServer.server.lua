--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Entity = require(Server.Framework.Core.Entity)
local Packets = require(Shared.Networking.Packets)
local DebugLogger = require(Shared.Debug.DebugLogger)

local function ValidateSlotIndex(SlotIndex: number): boolean
	return SlotIndex >= 1 and SlotIndex <= 10
end

local function HandleEquipTool(Player: Player, SlotIndex: number)
	if not ValidateSlotIndex(SlotIndex) then
		DebugLogger.Warning("ToolServer", "Invalid slot index from %s: %d", Player.Name, SlotIndex)
		return
	end

	local Character = Player.Character
	if not Character then
		DebugLogger.Warning("ToolServer", "%s has no character", Player.Name)
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Tool then
		DebugLogger.Warning("ToolServer", "No ToolComponent for %s", Player.Name)
		return
	end

	EntityInstance.Components.Tool:EquipTool(SlotIndex)
end

local function HandleUnequipTool(Player: Player, SlotIndex: number)
	if not ValidateSlotIndex(SlotIndex) then
		DebugLogger.Warning("ToolServer", "Invalid slot index from %s: %d", Player.Name, SlotIndex)
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Tool then
		return
	end

	if EntityInstance.Components.Tool:IsToolEquipped(SlotIndex) then
		EntityInstance.Components.Tool:UnequipTool()
	end
end

local function SendHotbarToClient(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Inventory then
		return
	end

	local InventoryComponent = EntityInstance.Components.Inventory
	local HotbarData: { [number]: any } = {}

	for SlotIndex = 1, 10 do
		local Item = InventoryComponent:GetItemInSlot(SlotIndex)
		if Item then
			HotbarData[SlotIndex] = {
				ToolId = Item.ToolId,
				ToolName = Item.ToolName,
				Icon = Item.ToolData and Item.ToolData.Icon or "",
			}
		end
	end

	Packets.HotbarUpdate:FireClient(Player, HotbarData)
	DebugLogger.Info("HotbarSync", "Sent hotbar data to %s", Player.Name)
end

local function SendEquippedToolToClient(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance or not EntityInstance.Components.Tool then
		return
	end

	local EquippedTool = EntityInstance.Components.Tool:GetEquippedTool()
	local SlotIndex = EquippedTool and EquippedTool.SlotIndex or nil

	Packets.EquippedToolUpdate:FireClient(Player, SlotIndex)
end

local function SendToClient(Player: Player)
	SendHotbarToClient(Player)
	SendEquippedToolToClient(Player)
end

Packets.RequestHotbarSync.OnServerEvent:Connect(SendToClient)
Packets.EquippedTool.OnServerEvent:Connect(HandleEquipTool)
Packets.UnequippedTool.OnServerEvent:Connect(HandleUnequipTool)

Players.PlayerAdded:Connect(function(Player: Player)
	Player.CharacterAdded:Connect(function(_Character: Model)
		task.wait(0.5)
		SendHotbarToClient(Player)
	end)
end)

DebugLogger.Info("ToolServer", "Tool system initialized")
