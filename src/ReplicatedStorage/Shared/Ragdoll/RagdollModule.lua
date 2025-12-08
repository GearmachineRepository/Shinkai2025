--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

type MotorData = {
	C0: CFrame,
	C1: CFrame,
	Part0: BasePart,
	Part1: BasePart
}

type RagdollModule = {
	PlayersCollisionGroup: string,
	CanCollide: boolean,
	Ragdoll: (self: RagdollModule, Character: Model) -> (),
	unRagdoll: (self: RagdollModule, Character: Model) -> (),
	CreateColliderPart: (self: RagdollModule, Part: BasePart) -> (),
	ReplaceJoints: (self: RagdollModule, Character: Model) -> (),
	ResetJoints: (self: RagdollModule, Character: Model) -> (),
	GetMotorData: (self: RagdollModule, Character: Model) -> {[Motor6D]: MotorData}
}

local RagdollModule: RagdollModule = {} :: any
RagdollModule.PlayersCollisionGroup = "Characters"
RagdollModule.CanCollide = false

local StoredMotorData: {[Model]: {[Motor6D]: MotorData}} = {}

if not PhysicsService:IsCollisionGroupRegistered("Uncollidable") then
	PhysicsService:RegisterCollisionGroup("Uncollidable")
end

if not PhysicsService:IsCollisionGroupRegistered(RagdollModule.PlayersCollisionGroup) then
	PhysicsService:RegisterCollisionGroup(RagdollModule.PlayersCollisionGroup)
end

PhysicsService:CollisionGroupSetCollidable("Uncollidable", RagdollModule.PlayersCollisionGroup, false)
PhysicsService:CollisionGroupSetCollidable("Uncollidable", "Uncollidable", RagdollModule.CanCollide)

function RagdollModule:Ragdoll(Character: Model): ()
	if not Character:GetAttribute("Ragdoll") then
		local IsNpc: boolean = Players:GetPlayerFromCharacter(Character) == nil
		local Humanoid: Humanoid? = Character:FindFirstChildWhichIsA("Humanoid")

		if not Humanoid then return end
		
		local Animator = Humanoid:FindFirstChild("Animator") :: Animator
		
		if not Animator then return end
	
		for _, Animation: AnimationTrack in Animator:GetPlayingAnimationTracks() do
			Animation:Stop()
		end

		Character:SetAttribute("Ragdoll", true)

		Humanoid.BreakJointsOnDeath = false
		Humanoid.AutoRotate = false
		Humanoid.RequiresNeck = true

		Humanoid.WalkSpeed = 0
		Humanoid.JumpPower = 0

		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)

		local HumanoidRootPart: BasePart? = Character:FindFirstChild("HumanoidRootPart") :: BasePart
		if HumanoidRootPart then
			HumanoidRootPart.CanCollide = false
		end

		if IsNpc then
			Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
		end

		self:ReplaceJoints(Character)
	end
end

function RagdollModule:unRagdoll(Character: Model): ()
	if Character:GetAttribute("Ragdoll") then
		local IsNpc: boolean = Players:GetPlayerFromCharacter(Character) == nil
		local Humanoid: Humanoid? = Character:FindFirstChildWhichIsA("Humanoid")

		if not Humanoid then return end
		if Humanoid.Health <= 0.1 then return end

		Character:SetAttribute("Ragdoll", false)

		Humanoid.AutoRotate = true
		Humanoid.RequiresNeck = false
		
		Humanoid.WalkSpeed = 16
		Humanoid.JumpPower = 50

		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)

		local HumanoidRootPart: BasePart = Character:FindFirstChild("HumanoidRootPart") :: BasePart
		if HumanoidRootPart then
			HumanoidRootPart.CanCollide = true
		end

		if IsNpc then
			Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end

		self:ResetJoints(Character)
	end
end

local FallbackAttachmentCFrames: {[string]: {CFrame}} = {
	["Neck"] = {CFrame.new(0, 1, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1), CFrame.new(0, -0.5, 0, 0, -1, 0, 1, 0, -0, 0, 0, 1)},
	["Left Shoulder"] = {CFrame.new(-1.3, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1), CFrame.new(0.2, 0.75, 0, -1, 0, 0, 0, -1, 0, 0, 0, 1)},
	["Right Shoulder"] = {CFrame.new(1.3, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1), CFrame.new(-0.2, 0.75, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)},
	["Left Hip"] = {CFrame.new(-0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
	["Right Hip"] = {CFrame.new(0.5, -1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1), CFrame.new(0, 1, 0, 0, 1, -0, -1, 0, 0, 0, 0, 1)},
}

local RagdollInstanceNames: {[string]: boolean} = {
	["RagdollAttachment"] = true,
	["RagdollConstraint"] = true,
	["ColliderPart"] = true,
}


function RagdollModule:GetMotorData(Character: Model): {[Motor6D]: MotorData}
	if StoredMotorData[Character] then
		return StoredMotorData[Character]
	end

	local MotorDataMap: {[Motor6D]: MotorData} = {}

	for _, Descendant: Instance in Character:GetDescendants() do
		if Descendant:IsA("Motor6D") then
			local Motor: Motor6D = Descendant :: Motor6D
			if Motor.Part0 and Motor.Part1 then
				MotorDataMap[Motor] = {
					C0 = Motor.C0,
					C1 = Motor.C1,
					Part0 = Motor.Part0,
					Part1 = Motor.Part1
				}
			end
		end
	end

	StoredMotorData[Character] = MotorDataMap
	return MotorDataMap
end

function RagdollModule:CreateColliderPart(Part: BasePart): ()
	if not Part then return end
	local RagdollColliderPart: Part = Instance.new("Part")
	RagdollColliderPart.Name = "ColliderPart"
	RagdollColliderPart.Size = Part.Size / 1.7
	RagdollColliderPart.Massless = true			
	RagdollColliderPart.CFrame = Part.CFrame
	RagdollColliderPart.Transparency = 1

	RagdollColliderPart.CollisionGroup = "Uncollidable"

	local WeldConstraint: WeldConstraint = Instance.new("WeldConstraint")
	WeldConstraint.Part0 = RagdollColliderPart
	WeldConstraint.Part1 = Part

	WeldConstraint.Parent = RagdollColliderPart
	RagdollColliderPart.Parent = Part
end


function RagdollModule:ReplaceJoints(Character: Model): ()
	local MotorDataMap: {[Motor6D]: MotorData} = self:GetMotorData(Character)

	for Motor: Motor6D, Data: MotorData in MotorDataMap do
		if not Motor.Parent then continue end
		if not Data.Part0 or not Data.Part1 then continue end

		Motor.Enabled = false

		local Attachment0: Attachment = Instance.new("Attachment")
		local Attachment1: Attachment = Instance.new("Attachment")
		Attachment0.CFrame = Data.C0
		Attachment1.CFrame = Data.C1

		Attachment0.Name = "RagdollAttachment"
		Attachment1.Name = "RagdollAttachment"

		self:CreateColliderPart(Data.Part1)

		local BallSocketConstraint: BallSocketConstraint = Instance.new("BallSocketConstraint")
		BallSocketConstraint.Attachment0 = Attachment0
		BallSocketConstraint.Attachment1 = Attachment1
		BallSocketConstraint.Name = "RagdollConstraint"

		BallSocketConstraint.Radius = 0.15
		BallSocketConstraint.LimitsEnabled = true
		BallSocketConstraint.TwistLimitsEnabled = true
		BallSocketConstraint.MaxFrictionTorque = 0
		BallSocketConstraint.Restitution = 0
		BallSocketConstraint.UpperAngle = 45
		BallSocketConstraint.TwistLowerAngle = -70
		BallSocketConstraint.TwistUpperAngle = 70

		Attachment0.Parent = Data.Part0
		Attachment1.Parent = Data.Part1
		BallSocketConstraint.Parent = Motor.Parent
	end
end

function RagdollModule:ResetJoints(Character: Model): ()
	local Humanoid: Humanoid? = Character:FindFirstChildWhichIsA("Humanoid")

	if Humanoid then	
		if Humanoid.Health < 0.1 then return end
		for _, Descendant: Instance in Character:GetDescendants() do
			if RagdollInstanceNames[Descendant.Name] then
				Descendant:Destroy()
			end

			if Descendant:IsA("Motor6D") then
				local Motor: Motor6D = Descendant :: Motor6D
				Motor.Enabled = true
			end
		end

		StoredMotorData[Character] = nil
	end
end

return RagdollModule