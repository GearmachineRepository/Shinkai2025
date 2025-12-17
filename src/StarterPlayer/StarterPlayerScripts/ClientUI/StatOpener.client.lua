--!strict

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

PlayerGui.DescendantAdded:Connect(function(Descendant: Instance)
	if Descendant:IsA("TextButton") and Descendant.Name == "Stats" and Descendant.Parent.Name == "Buttons" then
		Descendant.MouseButton1Click:Connect(function()
			local Hud = PlayerGui:FindFirstChild("Hud")
			if Hud then
				local Frame = Hud.Frames:FindFirstChild(Descendant.Name)
				Frame.Visible = not Frame.Visible
			end
		end)
	end
end)
