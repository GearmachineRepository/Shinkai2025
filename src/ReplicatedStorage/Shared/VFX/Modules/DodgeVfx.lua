--!strict
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local DashAssets = VfxAssets:WaitForChild("Dash")

local SfxAssets = Assets:WaitForChild("Sounds")
local DodgeSound = SfxAssets:WaitForChild("Dodge")

local SoundPlayer = require(Shared.Audio.SoundPlayer)

local DodgeVfx = {}

local TRAIL_ACTIVE_DURATION = 0.4

local GROUND_SAMPLE_INTERVAL = 0.1
local GROUND_RAY_EXTRA_DISTANCE = 4
local GROUND_SMOKE_MAX_LIFETIME = 3.0

type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

type DodgeVfxPayload = {
	Target: Model,
}

type AttachmentPair = {
	Top: Attachment,
	Bottom: Attachment,
}

local function GetDashTrailTemplate(): Trail?
	local TrailTemplate = DashAssets:FindFirstChild("DashTrail")
	if TrailTemplate and TrailTemplate:IsA("Trail") then
		return TrailTemplate
	end
	return nil
end

local function GetGroundSmokeTemplate(): ParticleEmitter?
	local SmokeTemplate = DashAssets:FindFirstChild("DashGroundSmoke")
	if SmokeTemplate and SmokeTemplate:IsA("ParticleEmitter") then
		return SmokeTemplate
	end
	return nil
end

local function SetEnabledIfParented(InstanceValue: any, IsEnabled: boolean)
	if InstanceValue.Parent == nil then
		return
	end

	if InstanceValue:IsA("Trail") or InstanceValue:IsA("ParticleEmitter") then
		InstanceValue.Enabled = IsEnabled
	end
end

local function DestroyIfParented(InstanceValue: Instance)
	if InstanceValue.Parent ~= nil then
		InstanceValue:Destroy()
	end
end

local function FindAllAttachmentPairs(Character: Model): { AttachmentPair }
	local AttachmentPairs: { AttachmentPair } = {}

	for _, Descendant in Character:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		local TrailTop: Attachment? = Descendant:FindFirstChild("TrailTop") :: Attachment?
		local TrailBottom: Attachment? = Descendant:FindFirstChild("TrailBottom") :: Attachment?

		if TrailTop and TrailTop:IsA("Attachment") and TrailBottom and TrailBottom:IsA("Attachment") then
			table.insert(AttachmentPairs, {
				Top = TrailTop,
				Bottom = TrailBottom,
			})
		end
	end

	return AttachmentPairs
end

local function GetSurfaceColor(RaycastResultValue: RaycastResult): Color3
	local HitInstance = RaycastResultValue.Instance

	if HitInstance:IsA("BasePart") then
		return HitInstance.Color
	end

	if HitInstance == workspace.Terrain then
		return workspace.Terrain:GetMaterialColor(RaycastResultValue.Material)
	end

	return Color3.new(1, 1, 1)
end

local function CreateGroundRaycastParams(Character: Model): RaycastParams
	local RaycastParamsInstance = RaycastParams.new()
	RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParamsInstance.IgnoreWater = false

	-- Exclude the dodging character and the Characters folder (if present)
	local CharactersFolder = workspace:FindFirstChild("Characters")
	if CharactersFolder then
		RaycastParamsInstance.FilterDescendantsInstances = { Character, CharactersFolder }
	else
		RaycastParamsInstance.FilterDescendantsInstances = { Character }
	end

	return RaycastParamsInstance
end

local function StartGroundSmoke(Character: Model, ActiveDuration: number): VfxInstance?
	local HumanoidInstance = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance == nil then
		return nil
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart == nil or not HumanoidRootPart:IsA("BasePart") then
		return nil
	end

	local SmokeTemplate = GetGroundSmokeTemplate()
	if SmokeTemplate == nil then
		warn("DodgeVfx: Could not find DashGroundSmoke in Assets/VFXAssets/Dash")
		return nil
	end

	local GroundAttachment = Instance.new("Attachment")
	GroundAttachment.Name = "DashGroundSmokeAttachment"
	GroundAttachment.Parent = HumanoidRootPart

	local RootHalfHeight = HumanoidRootPart.Size.Y * 0.5
	local HipHeight = HumanoidInstance.HipHeight
	GroundAttachment.Position = Vector3.new(0, -(RootHalfHeight + HipHeight), 0)

	local SmokeEmitter = SmokeTemplate:Clone()
	SmokeEmitter.Enabled = false
	SmokeEmitter.Parent = GroundAttachment

	local RaycastParamsInstance = CreateGroundRaycastParams(Character)

	local IsStopped = false
	local IsCleanedUp = false

	local function Stop()
		if IsStopped then
			return
		end

		IsStopped = true
		SetEnabledIfParented(SmokeEmitter, false)
	end

	local function UpdateSmokeFromGround()
		if IsStopped or IsCleanedUp then
			return
		end

		if SmokeEmitter.Parent == nil then
			return
		end

		local WorldOrigin = HumanoidRootPart.Position
		local RayDistance = RootHalfHeight + HipHeight + GROUND_RAY_EXTRA_DISTANCE
		local RayDirection = Vector3.new(0, -RayDistance, 0)

		local RaycastResultValue = workspace:Raycast(WorldOrigin, RayDirection, RaycastParamsInstance)

		if RaycastResultValue then
			SmokeEmitter.Color = ColorSequence.new(GetSurfaceColor(RaycastResultValue))
			SmokeEmitter.Enabled = true
		else
			SmokeEmitter.Enabled = false
		end
	end

	task.spawn(function()
		while not IsStopped and not IsCleanedUp do
			UpdateSmokeFromGround()
			task.wait(GROUND_SAMPLE_INTERVAL)
		end
	end)

	task.delay(ActiveDuration, Stop)

	local function Cleanup(Rollback: boolean?)
		if IsCleanedUp then
			return
		end

		IsCleanedUp = true
		Stop()

		if Rollback then
			DestroyIfParented(GroundAttachment)
		else
			Debris:AddItem(GroundAttachment, GROUND_SMOKE_MAX_LIFETIME + 0.2)
		end
	end

	return {
		Stop = Stop,
		Cleanup = Cleanup,
	}
end

function DodgeVfx.Play(_Character: Model, VfxData: unknown): VfxInstance?
	local TypedData = VfxData :: DodgeVfxPayload?
	if not TypedData or not TypedData.Target then
		return nil
	end

	local Target = TypedData.Target
	local AttachmentPairs = FindAllAttachmentPairs(Target)

	if #AttachmentPairs == 0 then
		warn("DodgeVfx: Could not find any TrailTop/TrailBottom attachment pairs in Target")
		return nil
	end

	local TrailTemplate = GetDashTrailTemplate()
	if not TrailTemplate then
		warn("DodgeVfx: Could not find DashTrail in Assets/VFXAssets/Dash")
		return nil
	end

	local CreatedTrails: { Trail } = {}
	local MaxLifetime = 0
	local IsCleanedUp = false

	SoundPlayer.Play(Target, DodgeSound)

	for _, Pair in AttachmentPairs do
		local TrailClone = TrailTemplate:Clone()
		TrailClone.Attachment0 = Pair.Top
		TrailClone.Attachment1 = Pair.Bottom
		TrailClone.Enabled = true
		TrailClone.Parent = Pair.Top.Parent

		if TrailClone.Lifetime > MaxLifetime then
			MaxLifetime = TrailClone.Lifetime
		end

		table.insert(CreatedTrails, TrailClone)
	end

	local GroundSmokeInstance = StartGroundSmoke(Target, TRAIL_ACTIVE_DURATION)

	local function Stop()
		if GroundSmokeInstance and GroundSmokeInstance.Stop then
			GroundSmokeInstance.Stop()
		end

		for _, TrailInstance in CreatedTrails do
			SetEnabledIfParented(TrailInstance, false)
		end
	end

	local function Cleanup(Rollback: boolean?)
		if IsCleanedUp then
			return
		end

		IsCleanedUp = true
		Stop()

		if GroundSmokeInstance then
			GroundSmokeInstance.Cleanup(Rollback)
			GroundSmokeInstance = nil
		end

		for _, TrailInstance in CreatedTrails do
			if TrailInstance.Parent == nil then
				continue
			end

			TrailInstance.Enabled = false

			if Rollback then
				TrailInstance:Destroy()
			else
				Debris:AddItem(TrailInstance, MaxLifetime + 0.5)
			end
		end

		table.clear(CreatedTrails)
	end

	task.delay(TRAIL_ACTIVE_DURATION, function()
		if IsCleanedUp then
			return
		end

		for _, TrailInstance in CreatedTrails do
			SetEnabledIfParented(TrailInstance, false)
		end
	end)

	task.delay(TRAIL_ACTIVE_DURATION + MaxLifetime + 0.5, function()
		if not IsCleanedUp then
			Cleanup(false)
		end
	end)

	return {
		Cleanup = Cleanup,
		Stop = Stop,
	}
end

return DodgeVfx
