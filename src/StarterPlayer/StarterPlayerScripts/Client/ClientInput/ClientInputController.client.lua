--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)

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
		Packets.PerformAction:Fire("Dash")
	end
end)
