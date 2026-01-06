--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local VfxPlayer = require(Shared.VFX.VfxPlayer)

local function GetCharacterFromSender(Sender: number | Instance): Model?
	if typeof(Sender) == "number" then
		local SenderPlayer = Players:GetPlayerByUserId(Sender)
		local SenderCharacter = SenderPlayer and SenderPlayer.Character
		if SenderCharacter and SenderCharacter:IsA("Model") then
			return SenderCharacter
		end
		return nil
	end

	if Sender:IsA("Player") then
		local SenderCharacter = Sender.Character
		if SenderCharacter and SenderCharacter:IsA("Model") then
			return SenderCharacter
		end
		return nil
	end

	if Sender:IsA("Model") then
		return Sender
	end

	return nil
end

local function SetupCharacterCleanup(TargetPlayer: Player)
	local function CleanupCharacter(Character: Model)
		VfxPlayer.CleanupAll(Character, false)
	end

	TargetPlayer.CharacterRemoving:Connect(CleanupCharacter)

	local function AttachAncestryFallback(Character: Model)
		Character.AncestryChanged:Connect(function(_, Parent)
			if Parent == nil then
				CleanupCharacter(Character)
			end
		end)
	end

	TargetPlayer.CharacterAdded:Connect(AttachAncestryFallback)

	local ExistingCharacter = TargetPlayer.Character
	if ExistingCharacter then
		AttachAncestryFallback(ExistingCharacter)
	end
end

local function OnVfxReplicated(Sender: number | Instance, VfxName: string, VfxData: unknown?)
	local Character = GetCharacterFromSender(Sender)
	if not Character then
		return
	end

	VfxPlayer.Play(Character, VfxName, VfxData)
end

Packets.PlayVfxReplicate.OnClientEvent:Connect(OnVfxReplicated)

Players.PlayerRemoving:Connect(function(RemovedPlayer: Player)
	local Character = RemovedPlayer.Character
	if Character then
		VfxPlayer.CleanupAll(Character, false)
	end
end)

for _, ExistingPlayer in Players:GetPlayers() do
	SetupCharacterCleanup(ExistingPlayer)
end

Players.PlayerAdded:Connect(SetupCharacterCleanup)
