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


-- Listen for server telling you to show UI
Packets.TreadmillModeSelected.OnClientEvent:Connect(function()
	-- Show your treadmill mode selection UI here
	TreadmillUI.Visible = true
end)

-- When player clicks "Max Stamina" button
MaxStaminaButton.MouseButton1Click:Connect(function()
	Packets.SelectTreadmillMode:Fire("MaxStamina")
	TreadmillUI.Visible = false
end)

-- When player clicks "Run Speed" button
RunSpeedButton.MouseButton1Click:Connect(function()
	Packets.SelectTreadmillMode:Fire("RunSpeed")
	TreadmillUI.Visible = false
end)