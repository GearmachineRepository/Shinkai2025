--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local SoundPlayer = require(Shared.General.SoundPlayer)

Packets.PlaySoundReplicate.OnClientEvent:Connect(function(SenderUserId: number, SoundName: string)
	local SenderPlayer = Players:GetPlayerByUserId(SenderUserId)
	if not SenderPlayer then
		return
	end

	local SenderCharacter = SenderPlayer.Character
	if not SenderCharacter then
		return
	end

	SoundPlayer.Play(SenderCharacter, SoundName)
end)
