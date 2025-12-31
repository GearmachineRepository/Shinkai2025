--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundPlayer = require(Shared.General.SoundPlayer)
local VfxEmitter = require(Shared.General.VfxEmitter)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local HitAssets = VfxAssets:WaitForChild("Hit")

local Sounds = Assets:WaitForChild("Sounds")
local PunchHits = Sounds:WaitForChild("PunchHits")
local BloodSpills = Sounds:WaitForChild("BloodSpills")
local BoneBreaks = Sounds:WaitForChild("BoneBreaks")

local HitVFX = {}

type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

type HitVfxData = {
	Target: Model?,
}

local DEFAULT_VFX_LIFETIME_SECONDS = 10
local HEALTH_PERCENT_SWAP = 45/100

function HitVFX.Play(_Character: Model, VfxData: any?): VfxInstance?
	local TypedData = VfxData :: HitVfxData?
	local Target = TypedData and TypedData.Target
	if not Target then
		return nil
	end

	local HitPosition: Vector3? = VfxData.HitPosition
	local SpawnPart: BasePart? = Target.PrimaryPart

	if not SpawnPart then
		return nil
	end

	local Humanoid = Target:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return nil
	end

	local OnHitFolder: Instance? = HitAssets:FindFirstChild("OnHit", true)
	if Humanoid.Health <= Humanoid.MaxHealth * HEALTH_PERCENT_SWAP then
        SoundPlayer.Play(Target, BloodSpills:GetChildren()[math.random(1, #BloodSpills:GetChildren())].Name)
        SoundPlayer.Play(Target, BoneBreaks:GetChildren()[math.random(1, #BoneBreaks:GetChildren())].Name)
		OnHitFolder = HitAssets:FindFirstChild("OnHitBleed", true)
	end

	SoundPlayer.Play(Target, PunchHits:GetChildren()[math.random(1, #PunchHits:GetChildren())].Name)

	if not OnHitFolder then
		return nil
	end

	local Playback = VfxEmitter.PlayFromTemplateFolder(Target, OnHitFolder, DEFAULT_VFX_LIFETIME_SECONDS, HitPosition)

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

return HitVFX
