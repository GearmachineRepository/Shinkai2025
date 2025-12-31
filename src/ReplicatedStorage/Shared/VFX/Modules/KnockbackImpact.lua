--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SoundPlayer = require(Shared.General.SoundPlayer)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local KnockbackImpactAssets = VfxAssets:WaitForChild("KnockbackImpact")

local Sounds = Assets:WaitForChild("Sounds")
local ImpactSounds = Sounds:WaitForChild("KnockbackImpact")

local KnockbackImpactVFX = {}

type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

type KnockbackImpactData = {
	Target: Model?,
	ImpactPosition: Vector3?,
	ImpactNormal: Vector3?,
	ImpactInstance: Instance?,
	KnockbackSpeed: number?,
	KnockbackDirection: Vector3?,
}

local DEFAULT_VFX_LIFETIME_SECONDS = 8
local HEAVY_IMPACT_SPEED_THRESHOLD = 60

local function GetImpactIntensity(Speed: number?): string
	if not Speed then
		return "Normal"
	end

	if Speed >= HEAVY_IMPACT_SPEED_THRESHOLD then
		return "Heavy"
	end

	return "Normal"
end

local function CreateImpactAttachment(ImpactPosition: Vector3, ImpactNormal: Vector3): Attachment
	local ImpactAttachment = Instance.new("Attachment")
	ImpactAttachment.Name = "KnockbackImpactAttachment"
	ImpactAttachment.WorldPosition = ImpactPosition
	ImpactAttachment.WorldCFrame = CFrame.lookAt(ImpactPosition, ImpactPosition + ImpactNormal) * CFrame.Angles(0, math.rad(-90), math.rad(90))
	ImpactAttachment.Parent = Workspace.Terrain

	return ImpactAttachment
end

local function EmitParticlesFromFolder(Attachment: Attachment, TemplateFolder: Instance)
	for _, Child in TemplateFolder:GetDescendants() do
		if Child:IsA("ParticleEmitter") then
			local ClonedEmitter = Child:Clone()
			ClonedEmitter.Parent = Attachment

			local EmitCount = ClonedEmitter:GetAttribute("EmitCount") or 10 :: number
			ClonedEmitter.Enabled = false
			ClonedEmitter:Emit(EmitCount :: number)
		end
	end
end

function KnockbackImpactVFX.Play(_Character: Model, VfxData: any?): VfxInstance?
	local TypedData = VfxData :: KnockbackImpactData?
	if not TypedData then
		return nil
	end

	local Target = TypedData.Target

	local ImpactPosition = TypedData.ImpactPosition
	local ImpactNormal = TypedData.ImpactNormal
	local KnockbackSpeed = TypedData.KnockbackSpeed

	if not ImpactPosition or not ImpactNormal then
		return nil
	end

	local Intensity = GetImpactIntensity(KnockbackSpeed)
	local EffectFolder = KnockbackImpactAssets:FindFirstChild(Intensity) or KnockbackImpactAssets:FindFirstChild("Normal")

	if not EffectFolder then
		return nil
	end

	local ImpactAttachment = CreateImpactAttachment(ImpactPosition, ImpactNormal)
	EmitParticlesFromFolder(ImpactAttachment, EffectFolder)

	if ImpactSounds and #ImpactSounds:GetChildren() > 0 then
		local SoundChildren = ImpactSounds:GetChildren()
		local RandomSound = SoundChildren[math.random(1, #SoundChildren)]
		if Target then
			SoundPlayer.Play(Target, RandomSound.Name, {
				Volume = if Intensity == "Heavy" then 0.75 else 0.25
			})
		end
	end

	Debris:AddItem(ImpactAttachment, DEFAULT_VFX_LIFETIME_SECONDS)

	local IsCleanedUp = false

	local function Stop()
		if IsCleanedUp then
			return
		end

		for _, Emitter in ImpactAttachment:GetChildren() do
			if Emitter:IsA("ParticleEmitter") then
				Emitter.Enabled = false
			end
		end
	end

	local function Cleanup(_Rollback: boolean?)
		if IsCleanedUp then
			return
		end

		IsCleanedUp = true

		if ImpactAttachment and ImpactAttachment.Parent then
			ImpactAttachment:Destroy()
		end
	end

	return {
		Cleanup = Cleanup,
		Stop = Stop,
	}
end

return KnockbackImpactVFX