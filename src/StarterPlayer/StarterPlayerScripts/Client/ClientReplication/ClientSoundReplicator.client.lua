--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local SoundPlayer = require(Shared.General.SoundPlayer)

Packets.PlaySoundReplicate.OnClientEvent:Connect(function(SenderUser: number | Instance, SoundName: string)
	local SenderCharacter = SenderUser :: Model

	if typeof(SenderUser) == "number" then
		local SenderPlayer = Players:GetPlayerByUserId(SenderUser)
		if not SenderPlayer then
			SenderCharacter = SenderPlayer.Character
		end
	end

	if not SenderCharacter then
		return
	end

	SoundPlayer.Play(SenderCharacter, SoundName)
end)
