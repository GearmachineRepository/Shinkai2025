--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local SoundPlayer = require(Shared.Audio.SoundPlayer)

Packets.PlaySoundReplicate.OnClientEvent:Connect(function(SenderUser: Player | Instance | number, SoundName: string)
	local SenderCharacter: Model? = nil

	if typeof(SenderUser) == "number" then
		local SenderPlayer: Player? = Players:GetPlayerByUserId(SenderUser)
		if SenderPlayer then
			SenderCharacter = SenderPlayer.Character
		end
	elseif typeof(SenderUser) == "Instance" then
		if SenderUser:IsA("Player") then
			SenderCharacter = (SenderUser :: Player).Character
		elseif SenderUser:IsA("Model") then
			SenderCharacter = SenderUser :: Model
		else
			SenderCharacter = SenderUser:FindFirstAncestorOfClass("Model")
		end
	end

	if not SenderCharacter then
		return
	end

	SoundPlayer.Play(SenderCharacter, SoundName)
end)