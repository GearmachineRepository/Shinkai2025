--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local VfxAssets = Assets:WaitForChild("VFXAssets")
local DashAssets = VfxAssets:WaitForChild("Dash")

local DodgeVfx = {}

local TRAIL_ACTIVE_DURATION = 0.4

local GROUND_SAMPLE_INTERVAL = 0.1
local GROUND_RAY_EXTRA_DISTANCE = 4
local GROUND_SMOKE_MAX_LIFETIME = 3.0

local RaycastParamsInstance = RaycastParams.new()
RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
RaycastParamsInstance.FilterDescendantsInstances = { workspace:WaitForChild("Characters") }
RaycastParamsInstance.IgnoreWater = false

type VfxInstance = {
	Cleanup: () -> (),
	Stop: (() -> ())?,
}

local function FindAllAttachmentPairs(Character: Model): { { Top: Attachment, Bottom: Attachment } }
	local AttachmentPairs: { { Top: Attachment, Bottom: Attachment } } = {}

	for _, Descendant in Character:GetDescendants() do
		if not Descendant:IsA("BasePart") then
			continue
		end

		local TrailTop: Attachment? = nil
		local TrailBottom: Attachment? = nil

		for _, Child in Descendant:GetChildren() do
			if Child:IsA("Attachment") then
				if Child.Name == "TrailTop" then
					TrailTop = Child
				elseif Child.Name == "TrailBottom" then
					TrailBottom = Child
				end
			end
		end

		if TrailTop and TrailBottom then
			table.insert(AttachmentPairs, {
				Top = TrailTop,
				Bottom = TrailBottom,
			})
		end
	end

	return AttachmentPairs
end

local function StartGroundSmoke(Character: Model, ActiveDuration: number): VfxInstance?
	local HumanoidInstance = Character:FindFirstChildOfClass("Humanoid")
	if not HumanoidInstance then
		return nil
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart or not HumanoidRootPart:IsA("BasePart") then
		return nil
	end

	local SmokeTemplate = DashAssets:FindFirstChild("DashGroundSmoke") :: ParticleEmitter?
	if not SmokeTemplate or not SmokeTemplate:IsA("ParticleEmitter") then
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

	local IsStopped = false

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

	local function Stop()
		if IsStopped then
			return
		end

		IsStopped = true

		if SmokeEmitter.Parent then
			SmokeEmitter.Enabled = false
		end
	end

	local function UpdateSmokeFromGround()
		if IsStopped then
			return
		end

		local WorldOrigin = HumanoidRootPart.Position
		local RayDistance = RootHalfHeight + HipHeight + GROUND_RAY_EXTRA_DISTANCE
		local RayDirection = Vector3.new(0, -RayDistance, 0)

		RaycastParamsInstance.FilterDescendantsInstances = { Character, workspace.Characters }

		local RaycastResultValue = workspace:Raycast(WorldOrigin, RayDirection, RaycastParamsInstance)

		if not SmokeEmitter.Parent then
			return
		end

		if RaycastResultValue then
			SmokeEmitter.Enabled = true
			SmokeEmitter.Color = ColorSequence.new(GetSurfaceColor(RaycastResultValue))
		else
			SmokeEmitter.Enabled = false
		end
	end

	task.spawn(function()
		while not IsStopped do
			UpdateSmokeFromGround()
			task.wait(GROUND_SAMPLE_INTERVAL)
		end
	end)

	task.delay(ActiveDuration, Stop)

	local function Cleanup()
		Stop()

		task.delay(GROUND_SMOKE_MAX_LIFETIME + 0.2, function()
			if GroundAttachment.Parent then
				GroundAttachment:Destroy()
			end
		end)
	end

	return {
		Stop = Stop,
		Cleanup = Cleanup,
	}
end

function DodgeVfx.Play(Character: Model, _VfxData: any?): VfxInstance?
	local AttachmentPairs = FindAllAttachmentPairs(Character)

	if #AttachmentPairs == 0 then
		warn("DodgeVfx: Could not find any TrailTop/TrailBottom attachment pairs in character")
		return nil
	end

	local TrailTemplate = DashAssets:FindFirstChild("DashTrail") :: Trail?
	if not TrailTemplate or not TrailTemplate:IsA("Trail") then
		warn("DodgeVfx: Could not find DashTrail in Assets/VFXAssets/Dash")
		return nil
	end

	local CreatedTrails: { Trail } = {}
	local MaxLifetime = 0

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

	task.delay(TRAIL_ACTIVE_DURATION, function()
		for _, Trail in CreatedTrails do
			if Trail and Trail.Parent then
				Trail.Enabled = false
			end
		end
	end)

	local GroundSmokeInstance = StartGroundSmoke(Character, TRAIL_ACTIVE_DURATION)

	local function Stop()
		if GroundSmokeInstance and GroundSmokeInstance.Stop then
			GroundSmokeInstance.Stop()
			GroundSmokeInstance = nil
		end

		for _, TrailInstance in CreatedTrails do
			if TrailInstance and TrailInstance.Parent then
				TrailInstance.Enabled = false
			end
		end
	end

	local function Cleanup()
		if GroundSmokeInstance then
			GroundSmokeInstance.Cleanup()
			GroundSmokeInstance = nil
		end

		for _, TrailInstance in CreatedTrails do
			if TrailInstance and TrailInstance.Parent then
				TrailInstance.Enabled = false
				game.Debris:AddItem(TrailInstance, 5)
			end
		end
		table.clear(CreatedTrails)
	end

	task.delay(TRAIL_ACTIVE_DURATION + MaxLifetime + 0.5, Cleanup)

	return {
		Cleanup = Cleanup,
		Stop = Stop,
	}
end

return DodgeVfx
