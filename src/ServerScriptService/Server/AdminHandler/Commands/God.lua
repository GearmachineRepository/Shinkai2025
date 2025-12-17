--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)

return {
	Description = "Toggle invulnerability",
	Usage = "!god",
	Execute = function(Player: Player)
		local Controller = CommandUtil.GetController(Player)
		if not Controller then return end

		local States = CommandUtil.States
		local CurrentValue = Controller.StateManager:GetState(States.INVULNERABLE)
		Controller.StateManager:SetState(States.INVULNERABLE, not CurrentValue)
		print("God mode:", not CurrentValue and "ON" or "OFF")
	end
}