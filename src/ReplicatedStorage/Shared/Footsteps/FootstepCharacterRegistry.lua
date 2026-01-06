--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FootstepMaterialMap = require(Shared.Footsteps.FootstepMaterialMap)
local FootstepSoundCatalog = require(Shared.Footsteps.FootstepSoundCatalog)
local FootstepSoundFactory = require(Shared.Footsteps.FootstepSoundFactory)
local FootstepCharacterUtil = require(Shared.Footsteps.FootstepCharacterUtil)

export type MaterialId = number

export type CharacterFootstepData = {
	SoundsById: { [MaterialId]: Sound },
	Connections: { RBXScriptConnection },
	Initializing: boolean,
}

local FootstepCharacterRegistry = {}

local CharacterData: { [Model]: CharacterFootstepData } = {}

local function EnsureCharacterEntry(Character: Model): CharacterFootstepData
	local Existing = CharacterData[Character]
	if Existing then
		return Existing
	end

	local Data: CharacterFootstepData = {
		SoundsById = {},
		Connections = {},
		Initializing = false,
	}

	CharacterData[Character] = Data
	return Data
end

function FootstepCharacterRegistry.GetCharacterData(Character: Model): CharacterFootstepData?
	return CharacterData[Character]
end

function FootstepCharacterRegistry.InitializeCharacter(Character: Model)
	local Data = EnsureCharacterEntry(Character)
	if Data.Initializing then
		return
	end

	if next(Data.SoundsById) ~= nil then
		return
	end

	local RootPart = FootstepCharacterUtil.GetHumanoidRootPart(Character)
	if not RootPart then
		Data.Initializing = true

		local Connection = Character.ChildAdded:Connect(function(Child: Instance)
			if Child.Name ~= "HumanoidRootPart" then
				return
			end

			if not Child:IsA("BasePart") then
				return
			end

			FootstepCharacterRegistry.InitializeCharacter(Character)
		end)

		table.insert(Data.Connections, Connection)

		Data.Initializing = false
		return
	end

	FootstepCharacterRegistry.CleanupCharacter(Character)

	Data = EnsureCharacterEntry(Character)

	local FootstepsGroup = FootstepSoundFactory.GetFootstepsSoundGroup()
	local SoundIdsByMaterialName = FootstepSoundCatalog.GetSoundIdsByMaterialName()

	for MaterialName, SoundIdList in SoundIdsByMaterialName do
		local MaterialIdValue = FootstepMaterialMap.GetId(MaterialName)
		if MaterialIdValue and #SoundIdList > 0 then
			local TemplateName = "Footstep_" .. MaterialName
			local TemplateSoundId = SoundIdList[1]
			Data.SoundsById[MaterialIdValue] = FootstepSoundFactory.CreateTemplateSound(
				RootPart,
				FootstepsGroup,
				TemplateSoundId,
				TemplateName
			)
		end
	end
end

function FootstepCharacterRegistry.CleanupCharacter(Character: Model)
	local Data = CharacterData[Character]
	if not Data then
		return
	end

	for _, Connection in Data.Connections do
		Connection:Disconnect()
	end

	for _, SoundInstance in Data.SoundsById do
		SoundInstance:Destroy()
	end

	CharacterData[Character] = nil
end

return FootstepCharacterRegistry
