--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FootstepConstants = require(Shared.Footsteps.FootstepConstants)
local FootstepSoundFactory = require(Shared.Footsteps.FootstepSoundFactory)
local FootstepCharacterUtil = require(Shared.Footsteps.FootstepCharacterUtil)
local FootstepMaterialQueries = require(Shared.Footsteps.FootstepMaterialQueries)
local FootstepCharacterRegistry = require(Shared.Footsteps.FootstepCharacterRegistry)
local FootstepSoundCatalog = require(Shared.Footsteps.FootstepSoundCatalog)

type MaterialId = FootstepMaterialQueries.MaterialId

local FootstepEngine = {}

local function ComputeVolumeFromSpeed(Speed: number): number
	local Alpha = math.clamp(
		(Speed - FootstepConstants.MIN_SPEED) / (FootstepConstants.MAX_SPEED - FootstepConstants.MIN_SPEED),
		0,
		1
	)
	return FootstepConstants.MIN_VOLUME + (FootstepConstants.MAX_VOLUME - FootstepConstants.MIN_VOLUME) * Alpha
end

function FootstepEngine.InitializeCharacter(Character: Model)
	FootstepCharacterRegistry.InitializeCharacter(Character)
end

function FootstepEngine.CleanupCharacter(Character: Model)
	FootstepCharacterRegistry.CleanupCharacter(Character)
end

function FootstepEngine.GetFloorMaterial(Character: Model): Enum.Material
	return FootstepMaterialQueries.GetFloorMaterial(Character)
end

function FootstepEngine.GetMaterialId(Character: Model): MaterialId?
	return FootstepMaterialQueries.GetMaterialId(Character)
end

function FootstepEngine.GetMaterialIdAtPosition(Character: Model, Position: Vector3): MaterialId?
	return FootstepMaterialQueries.GetMaterialIdAtPosition(Character, Position)
end

function FootstepEngine.PlayFootstep(Character: Model, MaterialIdValue: MaterialId?)
	local Data = FootstepCharacterRegistry.GetCharacterData(Character)
	if not Data then
		FootstepCharacterRegistry.InitializeCharacter(Character)
		Data = FootstepCharacterRegistry.GetCharacterData(Character)
	end
	if not Data then
		return
	end

	if next(Data.SoundsById) == nil then
		FootstepCharacterRegistry.InitializeCharacter(Character)
		Data = FootstepCharacterRegistry.GetCharacterData(Character)
		if not Data or next(Data.SoundsById) == nil then
			return
		end
	end

	local FinalMaterialId = MaterialIdValue or FootstepMaterialQueries.GetMaterialId(Character)
	if not FinalMaterialId then
		return
	end

	local TemplateSound = Data.SoundsById[FinalMaterialId]
	if not TemplateSound then
		return
	end

	local FloorMaterial = FootstepMaterialQueries.GetFloorMaterial(Character)
	local MaterialName = FloorMaterial.Name

	local RandomSoundId = FootstepSoundCatalog.GetRandomSoundId(MaterialName)

	local SoundInstance = TemplateSound:Clone()
	SoundInstance.Parent = TemplateSound.Parent

	if RandomSoundId then
		SoundInstance.SoundId = RandomSoundId
	end

	SoundInstance.PlaybackSpeed = 1 + (math.random() / 2)
	SoundInstance.Volume = ComputeVolumeFromSpeed(FootstepCharacterUtil.GetSpeed(Character))

	SoundInstance:Play()
	SoundInstance.Ended:Connect(function()
		SoundInstance:Destroy()
	end)
end

function FootstepEngine.GetSoundGroup(): SoundGroup
	return FootstepSoundFactory.GetFootstepsSoundGroup()
end

Players.PlayerRemoving:Connect(function(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	FootstepCharacterRegistry.CleanupCharacter(Character)
end)

return FootstepEngine
