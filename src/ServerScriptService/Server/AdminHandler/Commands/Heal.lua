--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Heal yourself",
	Usage = "!heal <amount>",
	Execute = function(Player: Player, Amount: string)
		local Controller = CommandUtil.GetController(Player)
		if not Controller then return end

		local HealAmount = tonumber(Amount) or 50
		Controller.Humanoid.Health = math.min(
			Controller.Humanoid.Health + HealAmount,
			Controller.Humanoid.MaxHealth
		)
		print("Healed", Player.Name, "for", HealAmount)
	end
}