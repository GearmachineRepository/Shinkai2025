--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundPlayer = require(Shared.General.SoundPlayer)
local VfxTemplatePlayer = require(Shared.General.VfxEmitter)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local GuardbreakVfx = VfxAssets:WaitForChild("Guardbreak")

local Sounds = Assets:WaitForChild("Sounds")
local GuardBreaks = Sounds:WaitForChild("Guardbreaks")

local GuardbrokenVFX = {}

type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

type HitVfxData = {
	Target: Model?,
}

local DEFAULT_VFX_LIFETIME_SECONDS = 10

function GuardbrokenVFX.Play(_Character: Model, VfxData: any?): VfxInstance?
	local TypedData = VfxData :: HitVfxData?
	local Target = TypedData and TypedData.Target
	if not Target then
		return nil
	end

	local Humanoid = Target:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return nil
	end

	local OnHitFolder: Instance? = GuardbreakVfx:FindFirstChild("GuardbreakNormal", true)

	SoundPlayer.Play(Target, GuardBreaks:GetChildren()[math.random(1, #GuardBreaks:GetChildren())].Name)

	if not OnHitFolder then
		return nil
	end

	local Playback = VfxTemplatePlayer.PlayFromTemplateFolder(Target, OnHitFolder, DEFAULT_VFX_LIFETIME_SECONDS)

	local function Stop()
		Playback.Cleanup()
	end

	local function Cleanup(_Rollback: boolean?)
		Playback.Cleanup()
	end

	return {
		Cleanup = Cleanup,
		Stop = Stop,
	}
end

return GuardbrokenVFX
