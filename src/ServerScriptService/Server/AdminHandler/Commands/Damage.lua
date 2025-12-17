--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Deal damage to yourself",
	Usage = "!damage <amount>",
	Execute = function(Player: Player, Amount: string)
		local Controller = CommandUtil.GetController(Player)
		if not Controller then return end

		local DamageAmount = tonumber(Amount) or 10
		Controller:TakeDamage(DamageAmount)
		print("Dealt", DamageAmount, "damage to", Player.Name)
	end
}