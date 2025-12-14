--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InputBuffer = require(ReplicatedStorage.Shared.Input.InputBuffer)

InputBuffer.OnAction(function(ActionName)
	print("Action fired:", ActionName)
end)
