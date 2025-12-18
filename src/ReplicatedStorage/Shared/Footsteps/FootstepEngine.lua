--!strict

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FootstepMaterialMap = require(Shared.Footsteps.FootstepMaterialMap)

type MaterialId = number

type CharacterFootstepData = {
	SoundsById: { [MaterialId]: Sound },
	Connections: { RBXScriptConnection },
	Initializing: boolean,
}

local FootstepEngine = {}

local TEMPLATE_VOLUME = 0.2
local MIN_VOLUME = 0.15
local MAX_VOLUME = 0.55
local MIN_SPEED = 0
local MAX_SPEED = 25

local RAY_DISTANCE_DOWN = 5
local POSITION_RAY_START_OFFSET = 0.5
local POSITION_RAY_DISTANCE_DOWN = 10

local FOOTSTEP_ROLLOFF_MIN_DISTANCE = 10
local FOOTSTEP_ROLLOFF_MAX_DISTANCE = 100

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
	GeneralConcrete = "rbxassetid://18984787734",
}

local SoundIdByMaterialName: { [string]: string } = {
	Grass = FootstepSoundGroups.GeneralGrass,
	LeafyGrass = FootstepSoundGroups.GeneralGrass,
	Mud = "rbxassetid://6441160246",
	Salt = FootstepSoundGroups.GeneralSoft,
	Sand = FootstepSoundGroups.GeneralSoft,
	Snow = FootstepSoundGroups.GeneralSoft,
	Ground = "rbxassetid://6540746817",

	Wood = FootstepSoundGroups.GeneralWood,
	WoodPlanks = FootstepSoundGroups.GeneralWood,
	Cardboard = FootstepSoundGroups.GeneralWood,
	Plaster = FootstepSoundGroups.GeneralWood,
	RoofShingles = FootstepSoundGroups.GeneralWood,

	Carpet = FootstepSoundGroups.GeneralFabric,
	Fabric = FootstepSoundGroups.GeneralFabric,
	Leather = FootstepSoundGroups.GeneralFabric,

	Plastic = FootstepSoundGroups.GeneralPlastic,
	SmoothPlastic = FootstepSoundGroups.GeneralPlastic,
	Neon = FootstepSoundGroups.GeneralPlastic,
	Rubber = FootstepSoundGroups.GeneralPlastic,
	ForceField = FootstepSoundGroups.GeneralPlastic,

	Basalt = FootstepSoundGroups.GeneralRock,
	CrackedLava = FootstepSoundGroups.GeneralRock,
	Glacier = FootstepSoundGroups.GeneralRock,
	Granite = FootstepSoundGroups.GeneralGranite,
	Limestone = FootstepSoundGroups.GeneralRock,
	Rock = FootstepSoundGroups.GeneralRock,
	Sandstone = FootstepSoundGroups.GeneralRock,

	Asphalt = FootstepSoundGroups.GeneralConcrete,
	Concrete = FootstepSoundGroups.GeneralConcrete,
	Pavement = FootstepSoundGroups.GeneralConcrete,
	Road = FootstepSoundGroups.GeneralConcrete,

	CeramicTiles = FootstepSoundGroups.GeneralTile,
	Glass = FootstepSoundGroups.GeneralTile,
	Slate = FootstepSoundGroups.GeneralTile,
	Brick = "rbxassetid://168786259",
	Cobblestone = "rbxassetid://142548009",
	ClayRoofTiles = "rbxassetid://9117382868",

	Metal = FootstepSoundGroups.GeneralMetal,
	CorrodedMetal = FootstepSoundGroups.GeneralMetal,
	DiamondPlate = "rbxassetid://481216891",
	Foil = "rbxassetid://142431247",

	Ice = "rbxassetid://19326880",
	Marble = "rbxassetid://134464111",
	Pebble = "rbxassetid://180239547",
	Splash = "rbxassetid://28604165",
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

local function EnsureCharacterEntry(Character: Model): CharacterFootstepData
	local Existing = CharacterData[Character]
	if Existing then
		return Existing
	end

	local Data: CharacterFootstepData = {
		SoundsById = {},
		Connections = {},
		Initializing = false,
	}

	CharacterData[Character] = Data
	return Data
end

function FootstepEngine.InitializeCharacter(Character: Model)
	local Data = EnsureCharacterEntry(Character)
	if Data.Initializing then
		return
	end

	if next(Data.SoundsById) ~= nil then
		return
	end

	local RootPart = GetHumanoidRootPart(Character)
	if not RootPart then
		Data.Initializing = true

		local Connection = Character.ChildAdded:Connect(function(Child: Instance)
			if Child.Name ~= "HumanoidRootPart" then
				return
			end

			local RootPartChild = Child
			if not RootPartChild:IsA("BasePart") then
				return
			end

			FootstepEngine.InitializeCharacter(Character)
		end)

		table.insert(Data.Connections, Connection)

		Data.Initializing = false
		return
	end

	FootstepEngine.CleanupCharacter(Character)

	Data = EnsureCharacterEntry(Character)

	local FootstepsGroup = GetFootstepsSoundGroup()

	for MaterialName, SoundId in SoundIdByMaterialName do
		local MaterialIdValue = FootstepMaterialMap.GetId(MaterialName)
		if MaterialIdValue then
			local TemplateName = "Footstep_" .. MaterialName
			Data.SoundsById[MaterialIdValue] = CreateTemplateSound(RootPart, FootstepsGroup, SoundId, TemplateName)
		end
	end
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

function FootstepEngine.PlayFootstep(Character: Model, MaterialIdValue: MaterialId?)
	local Data = CharacterData[Character]
	if not Data then
		FootstepEngine.InitializeCharacter(Character)
		Data = CharacterData[Character]
		if not Data then
			return
		end
	end

	if next(Data.SoundsById) == nil then
		FootstepEngine.InitializeCharacter(Character)
		Data = CharacterData[Character]
		if not Data or next(Data.SoundsById) == nil then
			return
		end
	end

	local FinalMaterialId = MaterialIdValue or FootstepEngine.GetMaterialId(Character)
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

Players.PlayerRemoving:Connect(function(Player: Player)
	local Character = Player.Character
	if not Character then
		return
	end

	FootstepEngine.CleanupCharacter(Character)
end)

return FootstepEngine
