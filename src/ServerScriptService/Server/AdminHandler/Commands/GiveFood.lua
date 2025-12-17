--!strict
local CommandUtil = require(script.Parent.Parent.CommandUtil)
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local CharacterController = require(Server.Entity.Core.CharacterController)

return {
	Description = "Give yourself a food item to test hunger",
	Usage = "!givefood [amount]",
	Execute = function(Player: Player, AmountStr: string?)
		local Character = CommandUtil.GetCharacter(Player)
		if not Character then
			warn("No character found")
			return
		end

		local HungerAmount = tonumber(AmountStr) or 30

        local Controller = CharacterController.Get(Character)
        if not Controller then
            warn("No controller found for", Character.Name)
            return
        end

        -- Check if player has HungerController
        if not Controller.HungerController then
            warn("No HungerController for", Character.Name)
            return
        end

        -- Feed the player
        Controller.HungerController:Feed(HungerAmount)

		print("Gave", Player.Name, "a food item that restores", HungerAmount, "hunger")
	end
}