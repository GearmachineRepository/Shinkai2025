local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Hud = PlayerGui:WaitForChild("Hud")
local Frames = Hud:WaitForChild("Frames")
local TreadmillUI = Frames:WaitForChild("TreadmillModeSelection")
local MaxStaminaButton = TreadmillUI:WaitForChild("MaxStaminaButton")
local RunSpeedButton = TreadmillUI:WaitForChild("RunSpeedButton")

Packets.TreadmillModeSelected.OnClientEvent:Connect(function(Toggle: boolean)
	TreadmillUI.Visible = Toggle
end)

MaxStaminaButton.MouseButton1Click:Connect(function()
	Packets.SelectTreadmillMode:Fire("MaxStamina")
	TreadmillUI.Visible = false
end)

RunSpeedButton.MouseButton1Click:Connect(function()
	Packets.SelectTreadmillMode:Fire("RunSpeed")
	TreadmillUI.Visible = false
end)
