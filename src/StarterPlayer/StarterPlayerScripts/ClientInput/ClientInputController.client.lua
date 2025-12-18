--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)
local DashController = require(Shared.Actions.DashController)

DashController.Initialize()

InputBuffer.OnAction(function(ActionName: string)
	if ActionName == "M1" then
		Packets.PerformAction:Fire("M1")
	elseif ActionName == "M2" then
		Packets.PerformAction:Fire("M2")
	elseif ActionName == "Block" then
		Packets.PerformAction:Fire("Block")
	elseif ActionName == "Skill1" then
		Packets.PerformAction:Fire("Skill1")
	elseif ActionName == "Skill2" then
		Packets.PerformAction:Fire("Skill2")
	elseif ActionName == "Skill3" then
		Packets.PerformAction:Fire("Skill3")
	elseif ActionName == "Skill4" then
		Packets.PerformAction:Fire("Skill4")
	elseif ActionName == "Skill5" then
		Packets.PerformAction:Fire("Skill5")
	elseif ActionName == "Skill6" then
		Packets.PerformAction:Fire("Skill6")
	elseif ActionName == "Dash" then
		DashController.RequestDash()
	end
end)

UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	DashController.SetKeyPressed(Input.KeyCode, true)
end)

UserInputService.InputEnded:Connect(function(Input: InputObject, GameProcessed: boolean)
	if GameProcessed then
		return
	end

	DashController.SetKeyPressed(Input.KeyCode, false)
end)
