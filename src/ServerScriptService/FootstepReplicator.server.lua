--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

Packets.Footplanted.OnServerEvent:Connect(function(Player, MaterialName, Position)
	local PlayerList = Players:GetPlayers()
	if #PlayerList <= 1 then return end

	for _, OtherPlayer in ipairs(PlayerList) do
		if OtherPlayer ~= Player then
			Packets.Footplanted:FireClient(OtherPlayer, MaterialName, Position, Player.UserId)
        end
    end
end)