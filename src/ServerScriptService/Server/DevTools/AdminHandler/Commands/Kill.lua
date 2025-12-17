--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Kill your character",
	Usage = "!kill",
	Execute = function(Player: Player)
		local Character = CommandUtil.GetCharacter(Player)
		if Character and Character:FindFirstChild("Humanoid") then
			Character.Humanoid.Health = 0
			print("Killed", Player.Name)
		end
	end
}