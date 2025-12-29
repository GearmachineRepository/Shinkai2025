--!strict

local Debris = game:GetService("Debris")

export type VfxPlayback = {
	Cleanup: () -> (),
}

local VfxEmitter = {}

local DEFAULT_EMIT_COUNT = 10
local DEFAULT_LIFETIME_SECONDS = 10

local function GetEmitCount(ParticleEmitter: ParticleEmitter): number
	local EmitCountAttribute = ParticleEmitter:GetAttribute("EmitCount")
	if typeof(EmitCountAttribute) == "number" then
		return EmitCountAttribute
	end

	return DEFAULT_EMIT_COUNT
end

local function FindTargetPart(TargetModel: Model, PartName: string): BasePart?
	local DirectChild = TargetModel:FindFirstChild(PartName)
	if DirectChild and DirectChild:IsA("BasePart") then
		return DirectChild
	end

	local Descendant = TargetModel:FindFirstChild(PartName, true)
	if Descendant and Descendant:IsA("BasePart") then
		return Descendant
	end

	return nil
end

local function EmitAllParticles(AttachmentInstance: Attachment)
	for _, Descendant in AttachmentInstance:GetDescendants() do
		if Descendant:IsA("ParticleEmitter") then
			local ParticleEmitter = Descendant :: ParticleEmitter
			ParticleEmitter.Enabled = false
			ParticleEmitter:Emit(GetEmitCount(ParticleEmitter))
		end
	end
end

function VfxEmitter.PlayFromTemplateFolder(
	TargetModel: Model,
	TemplateFolder: Instance,
	LifetimeSeconds: number?
): VfxPlayback
	local CleanupObjects: { Instance } = {}
	local Lifetime = LifetimeSeconds or DEFAULT_LIFETIME_SECONDS

	for _, TemplateChild in TemplateFolder:GetChildren() do
		if not TemplateChild:IsA("Attachment") then
			continue
		end

		local TemplateAttachment = TemplateChild :: Attachment
		local TargetPart = FindTargetPart(TargetModel, TemplateAttachment.Name)

		if not TargetPart then
			continue
		end

		local ClonedAttachment = TemplateAttachment:Clone()
		ClonedAttachment.Parent = TargetPart

		table.insert(CleanupObjects, ClonedAttachment)
		Debris:AddItem(ClonedAttachment, Lifetime)

		EmitAllParticles(ClonedAttachment)
	end

	local function Cleanup()
		for _, CleanupObject in CleanupObjects do
			if CleanupObject.Parent then
				CleanupObject:Destroy()
			end
		end
	end

	return {
		Cleanup = Cleanup,
	}
end

return VfxEmitter
