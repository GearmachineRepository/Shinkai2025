--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Set a stat value",
	Usage = "!setstat <StatName> <Value>",
	Execute = function(Player: Player, StatName: string, Value: string)
		if not StatName or not Value then
			warn("Usage: !setstat <StatName> <Value>")
			return
		end

		local Entity = CommandUtil.GetEntity(Player)
		if not Entity then
			return
		end

		local NumericValue = tonumber(Value)
		if not NumericValue then
			warn("Value must be a number")
			return
		end

		Entity.Stats:SetStat(StatName, NumericValue)
		print("Set", StatName, "=", NumericValue)
	end,
}
