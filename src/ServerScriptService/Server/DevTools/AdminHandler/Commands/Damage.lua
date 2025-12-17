--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Damage yourself by amount (tests damage system)",
	Usage = "!damage <amount>",
	Execute = function(Player: Player, AmountStr: string)
		local Amount = tonumber(AmountStr)
		if not Amount or Amount <= 0 then
			warn("Usage: !damage <amount>")
			return
		end

		local Entity = CommandUtil.GetEntity(Player)
		if not Entity then
			return
		end

		Entity:TakeDamage(Amount, Player)
		print(string.format("Dealt %d damage to %s", Amount, Player.Name))
	end,
}
