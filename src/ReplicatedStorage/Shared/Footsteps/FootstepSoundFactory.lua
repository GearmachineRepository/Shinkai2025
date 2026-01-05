--!strict

local SoundService = game:GetService("SoundService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FootstepConstants = require(Shared.Footsteps.FootstepConstants)

local FootstepSoundFactory = {}

function FootstepSoundFactory.GetFootstepsSoundGroup(): SoundGroup
	local Existing = SoundService:FindFirstChild("Footsteps")
	if Existing and Existing:IsA("SoundGroup") then
		return Existing
	end

	local NewGroup = Instance.new("SoundGroup")
	NewGroup.Name = "Footsteps"
	NewGroup.Volume = 1.0
	NewGroup.Parent = SoundService

	return NewGroup
end

function FootstepSoundFactory.CreateTemplateSound(
	Parent: Instance,
	SoundGroupInstance: SoundGroup,
	SoundId: string,
	Name: string
): Sound
	local SoundInstance = Instance.new("Sound")
	SoundInstance.Name = Name
	SoundInstance.SoundId = SoundId
	SoundInstance.Volume = FootstepConstants.TEMPLATE_VOLUME
	SoundInstance.RollOffMinDistance = FootstepConstants.FOOTSTEP_ROLLOFF_MIN_DISTANCE
	SoundInstance.RollOffMaxDistance = FootstepConstants.FOOTSTEP_ROLLOFF_MAX_DISTANCE
	SoundInstance.SoundGroup = SoundGroupInstance
	SoundInstance.Parent = Parent

	return SoundInstance
end

return FootstepSoundFactory
