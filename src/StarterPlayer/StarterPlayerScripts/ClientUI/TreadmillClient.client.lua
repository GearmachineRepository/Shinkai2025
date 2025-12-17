--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Hud: ScreenGui? = nil
local Frames: Instance? = nil
local TreadmillUI: Frame? = nil
local MaxStaminaButton: TextButton? = nil
local RunSpeedButton: TextButton? = nil

local function WaitForHud(): ScreenGui
	local ExistingHud = PlayerGui:WaitForChild("Hud", 5)
	if ExistingHud then
		return ExistingHud :: ScreenGui
	end

	PlayerGui.ChildAdded:Wait()
end

local function RebindUI()
	Hud = WaitForHud()
	Frames = Hud:WaitForChild("Frames")
	TreadmillUI = Frames:WaitForChild("TreadmillModeSelection") :: Frame
	MaxStaminaButton = TreadmillUI:WaitForChild("MaxStaminaButton") :: TextButton
	RunSpeedButton = TreadmillUI:WaitForChild("RunSpeedButton") :: TextButton

	MaxStaminaButton.MouseButton1Click:Connect(function()
		Packets.SelectTreadmillMode:Fire("MaxStamina")
		if TreadmillUI then
			TreadmillUI.Visible = false
		end
	end)

	RunSpeedButton.MouseButton1Click:Connect(function()
		Packets.SelectTreadmillMode:Fire("RunSpeed")
		if TreadmillUI then
			TreadmillUI.Visible = false
		end
	end)

	Hud.AncestryChanged:Connect(function(_, Parent)
		if not Parent then
			RebindUI()
		end
	end)
end

RebindUI()

Packets.TreadmillModeSelected.OnClientEvent:Connect(function(Toggle: boolean)
	if TreadmillUI then
		TreadmillUI.Visible = Toggle
	end
end)
