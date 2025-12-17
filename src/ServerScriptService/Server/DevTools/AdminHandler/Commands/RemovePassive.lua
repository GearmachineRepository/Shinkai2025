--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Remove a passive from your character",
	Usage = "!removepassive <PassiveName>",
	Execute = function(Player: Player, PassiveName: string)
		if not PassiveName then
			warn("Usage: !removepassive <PassiveName>")
			return
		end

		local Controller = CommandUtil.GetController(Player)
		if not Controller then return end

		Controller.PassiveController:RemovePassive(PassiveName)
		print("Removed passive:", PassiveName)
	end
}