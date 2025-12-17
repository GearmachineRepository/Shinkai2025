--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Add a passive to your character",
	Usage = "!addpassive <PassiveName>",
	Execute = function(Player: Player, PassiveName: string)
		if not PassiveName then
			warn("Usage: !addpassive <PassiveName>")
			return
		end

		local Controller = CommandUtil.GetController(Player)
		if not Controller then return end

		local Passive = CommandUtil.GetPassive(PassiveName)
		if not Passive then
			warn("Passive not found:", PassiveName)
			return
		end

		Controller.PassiveController:AddPassive(Passive)
		print("Added passive:", PassiveName)
	end
}