--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Set a state value",
	Usage = "!setstate <StateName> <Value>",
	Execute = function(Player: Player, StateName: string, Value: string)
		if not StateName or not Value then
			warn("Usage: !setstate <StateName> <Value>")
			return
		end

		local Entity = CommandUtil.GetEntity(Player)
		if not Entity then
			return
		end

		local ParsedValue
		if Value == "true" then
			ParsedValue = true
		elseif Value == "false" then
			ParsedValue = false
		else
			ParsedValue = tonumber(Value) or Value
		end

		Entity.States:SetState(StateName, ParsedValue)
		print("Set", StateName, "=", ParsedValue)
	end,
}
