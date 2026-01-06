--!strict

return {
	Description = "Respawn your character",
	Usage = "!respawn",
	Execute = function(Player: Player)
		Player:LoadCharacter()
		print("Respawned", Player.Name)
	end
}