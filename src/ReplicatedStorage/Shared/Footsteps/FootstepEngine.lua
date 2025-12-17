--!strict

local SoundService = game:GetService("SoundService")

local FootstepMaterialMap = require(script.Parent.FootstepMaterialMap)

local FootstepEngine = {}

export type MaterialId = FootstepMaterialMap.MaterialId

type CharacterFootstepData = {
	SoundsById: { [MaterialId]: Sound },
	Connections: { RBXScriptConnection },
}

local MIN_SPEED = 0
local MAX_SPEED = 30
local MIN_VOLUME = 0.3
local MAX_VOLUME = 1.0

local FOOTSTEP_ROLLOFF_MIN_DISTANCE = 5
local FOOTSTEP_ROLLOFF_MAX_DISTANCE = 150
local TEMPLATE_VOLUME = 0.65
local RAY_DISTANCE_DOWN = 50
local POSITION_RAY_DISTANCE_DOWN = 10
local POSITION_RAY_START_OFFSET = 1

local FootstepSoundGroups = {
	GeneralRock = "rbxassetid://18984787734",
	GeneralGranite = "rbxassetid://78958298131160",
	GeneralGrass = "rbxassetid://7003103812",
	GeneralWood = "rbxassetid://95897689644876",
	GeneralMetal = "rbxassetid://113703432248314",
	GeneralTile = "rbxassetid://78958298131160",
	GeneralSoft = "rbxassetid://75216555975721",
	GeneralPlastic = "rbxassetid://267454199",
	GeneralFabric = "rbxassetid://151760062",
	GeneralConcrete = "rbxassetid://70639393862430",
}

local SoundIdByMaterialName: { [string]: string } = {
	WoodPlanks = FootstepSoundGroups.GeneralWood,
	Wood = FootstepSoundGroups.GeneralWood,
	CeramicTiles = FootstepSoundGroups.GeneralTile,
	Splash = "rbxassetid://28604165",
	Sand = FootstepSoundGroups.GeneralSoft,
	Plastic = FootstepSoundGroups.GeneralPlastic,
	SmoothPlastic = FootstepSoundGroups.GeneralPlastic,
	Pebble = "rbxassetid://180239547",
	Metal = FootstepSoundGroups.GeneralMetal,
	Marble = "rbxassetid://134464111",
	Ice = "rbxassetid://19326880",
	Grass = FootstepSoundGroups.GeneralGrass,
	Granite = FootstepSoundGroups.GeneralGranite,
	Foil = "rbxassetid://142431247",
	Fabric = FootstepSoundGroups.GeneralFabric,
	DiamondPlate = "rbxassetid://481216891",
	CorrodedMetal = FootstepSoundGroups.GeneralMetal,
	Concrete = FootstepSoundGroups.GeneralConcrete,
	Cobblestone = "rbxassetid://142548009",
	Brick = "rbxassetid://168786259",

	Asphalt = FootstepSoundGroups.GeneralConcrete,
	Basalt = FootstepSoundGroups.GeneralRock,
	Rock = FootstepSoundGroups.GeneralRock,
	Limestone = FootstepSoundGroups.GeneralRock,
	Pavement = FootstepSoundGroups.GeneralConcrete,
	Salt = FootstepSoundGroups.GeneralSoft,
	Sandstone = FootstepSoundGroups.GeneralRock,
	Slate = FootstepSoundGroups.GeneralTile,
	CrackedLava = FootstepSoundGroups.GeneralRock,
	Neon = FootstepSoundGroups.GeneralPlastic,
	Glass = FootstepSoundGroups.GeneralTile,
	ForceField = FootstepSoundGroups.GeneralPlastic,
	LeafyGrass = FootstepSoundGroups.GeneralGrass,
	Mud = "rbxassetid://6441160246",
	Snow = FootstepSoundGroups.GeneralSoft,
	Ground = "rbxassetid://6540746817",
	Cardboard = FootstepSoundGroups.GeneralWood,
	Carpet = FootstepSoundGroups.GeneralFabric,
	Rubber = FootstepSoundGroups.GeneralPlastic,
	Leather = FootstepSoundGroups.GeneralFabric,
	Road = FootstepSoundGroups.GeneralConcrete,
	RoofShingles = FootstepSoundGroups.GeneralWood,
	ClayRoofTiles = "rbxassetid://9117382868",
	Glacier = FootstepSoundGroups.GeneralRock,
	Plaster = FootstepSoundGroups.GeneralWood,
}

local CharacterData: { [Model]: CharacterFootstepData } = {}

local function GetFootstepsSoundGroup(): SoundGroup
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

local function CreateTemplateSound(Parent: Instance, SoundGroup: SoundGroup, SoundId: string, Name: string): Sound
	local SoundInstance = Instance.new("Sound")
	SoundInstance.Name = Name
	SoundInstance.SoundId = SoundId
	SoundInstance.Volume = TEMPLATE_VOLUME
	SoundInstance.RollOffMinDistance = FOOTSTEP_ROLLOFF_MIN_DISTANCE
	SoundInstance.RollOffMaxDistance = FOOTSTEP_ROLLOFF_MAX_DISTANCE
	SoundInstance.SoundGroup = SoundGroup
	SoundInstance.Parent = Parent
	return SoundInstance
end

local function GetHumanoidRootPart(Character: Model): BasePart?
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end
	return nil
end

local function GetHumanoid(Character: Model): Humanoid?
	local HumanoidInstance = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		return HumanoidInstance
	end
	return nil
end

local function GetSpeed(Character: Model): number
	local RootPart = GetHumanoidRootPart(Character)
	if not RootPart then
		return 0
	end
	return RootPart.AssemblyLinearVelocity.Magnitude
end

local function ComputeVolumeFromSpeed(Speed: number): number
	local Alpha = math.clamp((Speed - MIN_SPEED) / (MAX_SPEED - MIN_SPEED), 0, 1)
	return MIN_VOLUME + (MAX_VOLUME - MIN_VOLUME) * Alpha
end

function FootstepEngine.InitializeCharacter(Character: Model)
	local RootPart = Character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not RootPart or not RootPart:IsA("BasePart") then
		return
	end

	FootstepEngine.CleanupCharacter(Character)

	local FootstepsGroup = GetFootstepsSoundGroup()

	local SoundsById: { [MaterialId]: Sound } = {}
	local Connections: { RBXScriptConnection } = {}

	for MaterialName, SoundId in SoundIdByMaterialName do
		local MaterialId = FootstepMaterialMap.GetId(MaterialName)
		if MaterialId then
			local TemplateName = "Footstep_" .. MaterialName
			SoundsById[MaterialId] = CreateTemplateSound(RootPart, FootstepsGroup, SoundId, TemplateName)
		end
	end

	CharacterData[Character] = {
		SoundsById = SoundsById,
		Connections = Connections,
	}
end

function FootstepEngine.CleanupCharacter(Character: Model)
	local Data = CharacterData[Character]
	if not Data then
		return
	end

	for _, Connection in Data.Connections do
		Connection:Disconnect()
	end

	for _, SoundInstance in Data.SoundsById do
		SoundInstance:Destroy()
	end

	CharacterData[Character] = nil
end

function FootstepEngine.GetFloorMaterial(Character: Model): Enum.Material
	local RootPart = GetHumanoidRootPart(Character)
	local HumanoidInstance = GetHumanoid(Character)

	if not RootPart or not HumanoidInstance then
		return Enum.Material.Air
	end

	local RaycastParamsInstance = RaycastParams.new()
	RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParamsInstance.FilterDescendantsInstances = { Character }

	local RayOrigin = RootPart.Position
	local RayDirection = Vector3.new(0, -RAY_DISTANCE_DOWN, 0)

	local Result = workspace:Raycast(RayOrigin, RayDirection, RaycastParamsInstance)
	if Result then
		return Result.Material
	end

	if HumanoidInstance.FloorMaterial ~= Enum.Material.Air then
		return HumanoidInstance.FloorMaterial
	end

	return Enum.Material.Air
end

function FootstepEngine.GetMaterialId(Character: Model): MaterialId?
	local FloorMaterial = FootstepEngine.GetFloorMaterial(Character)
	if FloorMaterial == Enum.Material.Air then
		return nil
	end

	return FootstepMaterialMap.GetId(FloorMaterial.Name)
end

function FootstepEngine.GetMaterialIdAtPosition(Character: Model, Position: Vector3): MaterialId?
	local RaycastParamsInstance = RaycastParams.new()
	RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParamsInstance.FilterDescendantsInstances = { Character }

	local RayOrigin = Position + Vector3.new(0, POSITION_RAY_START_OFFSET, 0)
	local RayDirection = Vector3.new(0, -POSITION_RAY_DISTANCE_DOWN, 0)

	local Result = workspace:Raycast(RayOrigin, RayDirection, RaycastParamsInstance)
	if Result then
		return FootstepMaterialMap.GetId(Result.Material.Name)
	end

	return FootstepEngine.GetMaterialId(Character)
end

function FootstepEngine.PlayFootstep(Character: Model, MaterialId: MaterialId?)
	local Data = CharacterData[Character]
	if not Data then
		return
	end

	local FinalMaterialId = MaterialId or FootstepEngine.GetMaterialId(Character)
	if not FinalMaterialId then
		return
	end

	local TemplateSound = Data.SoundsById[FinalMaterialId]
	if not TemplateSound then
		return
	end

	local SoundInstance = TemplateSound:Clone()
	SoundInstance.Parent = TemplateSound.Parent
	SoundInstance.PlaybackSpeed = 1 + (math.random() / 2)
	SoundInstance.Volume = ComputeVolumeFromSpeed(GetSpeed(Character))

	SoundInstance:Play()
	SoundInstance.Ended:Connect(function()
		SoundInstance:Destroy()
	end)
end

function FootstepEngine.GetSoundGroup(): SoundGroup
	return GetFootstepsSoundGroup()
end

return FootstepEngine
