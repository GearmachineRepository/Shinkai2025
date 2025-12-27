--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundPlayer = require(Shared.General.SoundPlayer)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local HitAssets = VfxAssets:WaitForChild("Hit")

local HitVFX = {}

type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

function HitVFX.Play(_Character: Model, VfxData: any?): VfxInstance?
    local CleanupTable: { any } = {}

    local Target = VfxData.Target
    if not Target then return end
    if not Target.PrimaryPart then return nil end

    SoundPlayer.Play(Target, "Hit1")

    local OnHitVFX = HitAssets:findFirstChild("OnHit")
    if OnHitVFX then
        for _, Particle in pairs(OnHitVFX:GetChildren()) do
            local NewParticle = Particle:Clone()
            NewParticle.Parent = Target.PrimaryPart
            NewParticle:Emit(10)
            table.insert(CleanupTable, NewParticle)

            game.Debris:AddItem(NewParticle, 10)
        end
    end

	local function Stop()
        for _, Object in pairs(CleanupTable) do
            Object:Destroy()
        end
	end

	local function Cleanup(_Rollback: boolean?)
        for _, Object in pairs(CleanupTable) do
            Object:Destroy()
        end
	end

	return {
		Cleanup = Cleanup,
		Stop = Stop,
	}
end

return HitVFX
