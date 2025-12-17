--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Set walk speed multiplier",
	Usage = "!speed <multiplier>",
	Execute = function(Player: Player, Multiplier: string)
		local Controller = CommandUtil.GetController(Player)
		if not Controller then return end

		local Mult = tonumber(Multiplier) or 1
		Controller.Humanoid.WalkSpeed = 16 * Mult
		print("Speed set to", Controller.Humanoid.WalkSpeed)
	end
}