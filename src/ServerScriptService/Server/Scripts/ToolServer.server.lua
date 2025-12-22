--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)

local function ValidateSlotIndex(SlotIndex: number): boolean
	return SlotIndex >= 1 and SlotIndex <= 10
end

local function HandleEquipTool(Player: Player, SlotIndex: number)
	if not ValidateSlotIndex(SlotIndex) then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Ensemble.GetEntity(Character)
	if not EntityInstance then
		return
	end

	local ToolComponent = EntityInstance:GetComponent("Tool")
	if not ToolComponent then
		return
	end

	ToolComponent:EquipTool(SlotIndex)
end

local function HandleUnequipTool(Player: Player, SlotIndex: number)
	if not ValidateSlotIndex(SlotIndex) then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Ensemble.GetEntity(Character)
	if not EntityInstance then
		return
	end

	local ToolComponent = EntityInstance:GetComponent("Tool")
	if not ToolComponent then
		return
	end

	if ToolComponent:IsToolEquipped(SlotIndex) then
		ToolComponent:UnequipTool()
	end
end

local function SendHotbarToClient(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Ensemble.GetEntity(Character)
	if not EntityInstance  then
		return
	end

	local InventoryComponent = EntityInstance:GetComponent("Inventory")
	if not InventoryComponent then
		return
	end
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
end

local function SendEquippedToolToClient(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Ensemble.GetEntity(Character)
	if not EntityInstance then
		return
	end

	local ToolComponent = EntityInstance:GetComponent("Tool")
	if not ToolComponent then
		return
	end

	local EquippedTool = ToolComponent:GetEquippedTool()
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
