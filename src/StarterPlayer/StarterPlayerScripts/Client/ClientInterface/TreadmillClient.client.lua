--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local TreadmillUI: Frame? = nil
local MaxStaminaButton: TextButton? = nil
local RunSpeedButton: TextButton? = nil

local Maid = require(Shared.Utility.Maid)
local HudBinder = require(Shared.Utility.HudBinder)

local UiMaid = Maid.new() :: any

local function RebindUI()
	UiMaid:DoCleaning()

	local Refs = HudBinder.Get()
	local Frames = Refs.Frames

	TreadmillUI = Frames:WaitForChild("TreadmillModeSelection") :: Frame
	MaxStaminaButton = TreadmillUI:WaitForChild("MaxStaminaButton") :: TextButton
	RunSpeedButton = TreadmillUI:WaitForChild("RunSpeedButton") :: TextButton

	UiMaid:GiveTask(MaxStaminaButton.MouseButton1Click:Connect(function()
		Packets.SelectTreadmillMode:Fire("MaxStamina")
		TreadmillUI.Visible = false
	end))

	UiMaid:GiveTask(RunSpeedButton.MouseButton1Click:Connect(function()
		Packets.SelectTreadmillMode:Fire("RunSpeed")
		TreadmillUI.Visible = false
	end))
end

RebindUI()
UiMaid:GiveTask(HudBinder.OnChanged(RebindUI))

Packets.TreadmillModeSelected.OnClientEvent:Connect(function(Toggle: boolean)
	if TreadmillUI then
		TreadmillUI.Visible = Toggle
	end
end)
