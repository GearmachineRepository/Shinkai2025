--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local VfxModules = Shared:WaitForChild("VFX"):WaitForChild("Modules")

export type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

local VfxPlayer = {}

local ActiveVfxByCharacter: { [Model]: { [string]: VfxInstance } } = {}

local function GetVfxModule(VfxName: string): any?
	local VfxModule = VfxModules:FindFirstChild(VfxName)
	if not VfxModule or not VfxModule:IsA("ModuleScript") then
		warn("VFX module not found:", VfxName)
		return nil
	end

	local Success, Result = pcall(require, VfxModule)
	if not Success then
		warn("Failed to load VFX module:", VfxName, Result)
		return nil
	end

	return Result
end

function VfxPlayer.Play(Character: Model, VfxName: string, VfxData: any?): VfxInstance?
	local VfxModule = GetVfxModule(VfxName)
	if not VfxModule or not VfxModule.Play then
		return nil
	end

	VfxPlayer.Cleanup(Character, VfxName, false)

	local VfxInstance = VfxModule.Play(Character, VfxData)
	if not VfxInstance then
		return nil
	end

	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		CharacterVfx = {}
		ActiveVfxByCharacter[Character] = CharacterVfx
	end

	CharacterVfx[VfxName] = VfxInstance

	return VfxInstance
end

function VfxPlayer.PlayLocal(VfxName: string, VfxData: any?): VfxInstance?
	local Character = Players.LocalPlayer.Character
	if not Character then
		return nil
	end

	local VfxInstance = VfxPlayer.Play(Character, VfxName, VfxData)
	Packets.PlayVfx:Fire(VfxName, VfxData)

	return VfxInstance
end

function VfxPlayer.Stop(Character: Model, VfxName: string)
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return
	end

	local VfxInstance = CharacterVfx[VfxName]
	if not VfxInstance then
		return
	end

	if VfxInstance.Stop then
		VfxInstance.Stop()
	end

	CharacterVfx[VfxName] = nil
end

function VfxPlayer.Cleanup(Character: Model, VfxName: string, Rollback: boolean?)
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return
	end

	local VfxInstance = CharacterVfx[VfxName]
	if not VfxInstance then
		return
	end

	VfxInstance.Cleanup(Rollback)
	CharacterVfx[VfxName] = nil
end

function VfxPlayer.CleanupAll(Character: Model)
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return
	end

	for _VfxName, VfxInstance in CharacterVfx do
		VfxInstance.Cleanup(false)
	end

	ActiveVfxByCharacter[Character] = nil
end

function VfxPlayer.OnVfxReplicated(SenderUserId: number, VfxName: string, VfxData: any?)
	local SenderPlayer = Players:GetPlayerByUserId(SenderUserId)
	if not SenderPlayer then
		return
	end

	local SenderCharacter = SenderPlayer.Character
	if not SenderCharacter then
		return
	end

	VfxPlayer.Play(SenderCharacter, VfxName, VfxData)
end

if RunService:IsClient() then
	Packets.PlayVfxReplicate.OnClientEvent:Connect(VfxPlayer.OnVfxReplicated)

	Players.PlayerRemoving:Connect(function(Player: Player)
		if Player.Character then
			VfxPlayer.CleanupAll(Player.Character)
		end
	end)

	local function OnCharacterRemoving(Character: Model)
		VfxPlayer.CleanupAll(Character)
	end

	for _, Player in Players:GetPlayers() do
		if Player.Character then
			Player.Character.AncestryChanged:Connect(function(_, Parent)
				if not Parent then
					OnCharacterRemoving(Player.Character)
				end
			end)
		end

		Player.CharacterRemoving:Connect(OnCharacterRemoving)
	end

	Players.PlayerAdded:Connect(function(Player: Player)
		Player.CharacterRemoving:Connect(OnCharacterRemoving)
	end)
end

Players.PlayerRemoving:Connect(function(Player: Player)
	if Player.Character then
		VfxPlayer.CleanupAll(Player.Character)
	end
end)

local function OnCharacterRemoving(Character: Model)
	VfxPlayer.CleanupAll(Character)
end

for _, Player in Players:GetPlayers() do
	if Player.Character then
		Player.Character.AncestryChanged:Connect(function(_, Parent)
			if not Parent then
				OnCharacterRemoving(Player.Character)
			end
		end)
	end

	Player.CharacterRemoving:Connect(OnCharacterRemoving)
end

Players.PlayerAdded:Connect(function(Player: Player)
	Player.CharacterRemoving:Connect(OnCharacterRemoving)
end)

return VfxPlayer
