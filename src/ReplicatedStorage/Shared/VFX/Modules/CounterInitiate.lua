--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundPlayer = require(Shared.Audio.SoundPlayer)
local VfxTemplatePlayer = require(Shared.VFX.VfxEmitter)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local GeneralVFXAssets = VfxAssets:WaitForChild(script.Name)

local Sounds = Assets:WaitForChild("Sounds")
local CounterSFX = Sounds:WaitForChild("Counter")

local CounterInitVFX = {}

type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

type HitVfxData = {
	Target: Model?,
}

local DEFAULT_VFX_LIFETIME_SECONDS = 10

function CounterInitVFX.Play(_Character: Model, VfxData: any?): VfxInstance?
	local TypedData = VfxData :: HitVfxData?
	local Target = TypedData and TypedData.Target
	if not Target then
		return nil
	end

	local Humanoid = Target:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return nil
	end

	local HitPosition: Vector3? = VfxData.HitPosition

	local OnHitFolder: Instance? = GeneralVFXAssets

	-- SoundPlayer.Play(Target, Swings:GetChildren()[math.random(1, #Swings:GetChildren())].Name)
	SoundPlayer.Play(Target, CounterSFX:GetChildren()[math.random(1, #CounterSFX:GetChildren())].Name)

	if not OnHitFolder then
		return nil
	end

	local Playback = VfxTemplatePlayer.PlayFromTemplateFolder(Target, OnHitFolder, DEFAULT_VFX_LIFETIME_SECONDS, HitPosition)

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

return CounterInitVFX
