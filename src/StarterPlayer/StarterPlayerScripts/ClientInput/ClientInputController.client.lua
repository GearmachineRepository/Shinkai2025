--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputBuffer = require(ReplicatedStorage.Shared.General.InputBuffer)

InputBuffer.OnAction(function(ActionName)
	print("Action fired:", ActionName)
end)
