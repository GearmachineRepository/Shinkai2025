local FootstepEngine = {}

local SoundService = game:GetService("SoundService")

local minSpeed = 0
local maxSpeed = 30
local minVol   = 0.3
local maxVol   = 1.0

-- Sound categories
local FootstepSoundGroups = {
	GeneralRock = "rbxassetid://18984787734",
	GeneralGranite = "rbxassetid://9114657434",
	GeneralGrass = "rbxassetid://7003103812",
	GeneralWood = "rbxassetid://95897689644876",
	GeneralMetal = "rbxassetid://113703432248314",
	GeneralTile = "rbxassetid://481217914",
	GeneralSoft = "rbxassetid://75216555975721", -- Sand-like sounds
	GeneralPlastic = "rbxassetid://267454199",
	GeneralFabric = "rbxassetid://151760062",
	GeneralConcrete = "rbxassetid://70639393862430",
}

local Footsteps = {
	["WoodPlanks"] = FootstepSoundGroups.GeneralWood,
	["Wood"] = FootstepSoundGroups.GeneralWood,
	["CeramicTiles"] = FootstepSoundGroups.GeneralTile,
	["Splash"] = "rbxassetid://28604165", -- Unique sound
	["Sand"] = FootstepSoundGroups.GeneralSoft,
	["Plastic"] = FootstepSoundGroups.GeneralPlastic,
	["Pebble"] = "rbxassetid://180239547", -- Unique sound
	["Metal"] = FootstepSoundGroups.GeneralMetal,
	["Marble"] = "rbxassetid://134464111", -- Unique marble sound
	["Ice"] = "rbxassetid://19326880", -- Unique sound
	["Grass"] = FootstepSoundGroups.GeneralGrass,
	["Granite"] = FootstepSoundGroups.GeneralGranite,
	["Foil"] = "rbxassetid://142431247", -- Unique sound
	["Fabric"] = FootstepSoundGroups.GeneralFabric,
	["Diamond"] = "rbxassetid://481216891", -- Unique sound
	["CorrodedMetal"] = FootstepSoundGroups.GeneralMetal,
	["Concrete"] = FootstepSoundGroups.GeneralConcrete,
	["Cobblestone"] = "rbxassetid://142548009", -- Unique sound
	["Brick"] = "rbxassetid://168786259", -- Unique sound

	-- Additional materials using categories
	["Asphalt"] = FootstepSoundGroups.GeneralConcrete,
	["Basalt"] = FootstepSoundGroups.GeneralRock,
	["Rock"] = FootstepSoundGroups.GeneralRock,
	["Limestone"] = FootstepSoundGroups.GeneralRock,
	["Pavement"] = FootstepSoundGroups.GeneralConcrete,
	["Salt"] = FootstepSoundGroups.GeneralSoft,
	["Sandstone"] = FootstepSoundGroups.GeneralRock,
	["Slate"] = FootstepSoundGroups.GeneralTile,
	["CrackedLava"] = FootstepSoundGroups.GeneralRock,
	["Neon"] = FootstepSoundGroups.GeneralPlastic,
	["Glass"] = FootstepSoundGroups.GeneralTile,
	["ForceField"] = FootstepSoundGroups.GeneralPlastic,
	["LeafyGrass"] = FootstepSoundGroups.GeneralGrass,
	["Mud"] = "rbxassetid://6441160246",
	["Snow"] = FootstepSoundGroups.GeneralSoft,
	["Ground"] = "rbxassetid://6540746817",
	["Cardboard"] = FootstepSoundGroups.GeneralWood,
	["Carpet"] = FootstepSoundGroups.GeneralFabric,
	["Rubber"] = FootstepSoundGroups.GeneralPlastic,
	["Leather"] = FootstepSoundGroups.GeneralFabric,
	["Road"] = FootstepSoundGroups.GeneralConcrete,

	-- Special case for air/no material
	["Air"] = nil,
}

-- Store character footstep data
local CharacterData = {}

-- Get or create Footsteps SoundGroup
local function GetFootstepsSoundGroup()
	local footstepsGroup = SoundService:FindFirstChild("Footsteps")
	if not footstepsGroup then
		footstepsGroup = Instance.new("SoundGroup")
		footstepsGroup.Name = "Footsteps"
		footstepsGroup.Parent = SoundService
		-- You can set default volume here
		footstepsGroup.Volume = 1.0
	end
	return footstepsGroup
end

-- Initialize footstep sounds for a character
function FootstepEngine.InitializeCharacter(Character: Model)
	local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart", 5)
	if not HumanoidRootPart then return end

	-- Clean up existing data
	FootstepEngine.CleanupCharacter(Character)

	-- Get the Footsteps SoundGroup
	local footstepsGroup = GetFootstepsSoundGroup()

	-- Create footstep sounds container
	local footstepSounds = {}
	local connections = {}

	-- Pre-load all material sounds for this character
	for materialName, soundId in pairs(Footsteps) do
		if soundId then
			local sound = Instance.new("Sound")
			sound.Name = "Footstep_" .. materialName
			sound.SoundId = soundId
			sound.Volume = 0.65
			sound.RollOffMinDistance = 5
			sound.RollOffMaxDistance = 150
			--sound.Archivable = false
			sound.SoundGroup = footstepsGroup -- Connect to SoundGroup!
			sound.Parent = HumanoidRootPart
			footstepSounds[materialName] = sound
		end
	end

	-- Set up footplant attribute listener
	local footplantConnection = Character.AttributeChanged:Connect(function(AttributeName: string)
		if AttributeName == "Footplanted" then
			local Value = Character:GetAttribute(AttributeName)
			if Value then
				FootstepEngine.PlayFootstep(Character)
			end
		end
	end)

	table.insert(connections, footplantConnection)

	-- Store character data
	CharacterData[Character] = {
		sounds = footstepSounds,
		connections = connections
	}
end

-- Clean up character data
function FootstepEngine.CleanupCharacter(Character: Model)
	local data = CharacterData[Character]
	if data then
		-- Disconnect all connections
		for _, connection in pairs(data.connections) do
			connection:Disconnect()
		end

		-- Destroy all sounds
		for _, sound in pairs(data.sounds) do
			sound:Destroy()
		end

		CharacterData[Character] = nil
	end
end

-- Play footstep sound for character
function FootstepEngine.PlayFootstep(Character: Model, materialOverride: string?)
	local data = CharacterData[Character]
	if not data then return end

	local floorMaterial: Enum.Material?

	if materialOverride then
		-- Caller provides material (string)
		floorMaterial = Enum.Material[materialOverride]
	else
		-- Normal detection
		floorMaterial = FootstepEngine.GetFloorMaterial(Character)
	end

	if not floorMaterial or floorMaterial == Enum.Material.Air then return end

	-- Use the template sound for this material
	local templateSound = data.sounds[floorMaterial.Name]
	if not templateSound then return end

	-- Clone so footsteps can overlap naturally
	local sound = templateSound:Clone()
	sound.Parent = templateSound.Parent
	sound.PlaybackSpeed = 1 + (math.random() / 2)

	-- Get actual movement speed
	local HRP = Character:FindFirstChild("HumanoidRootPart")
	local speed = 0

	if HRP then
		speed = HRP.AssemblyLinearVelocity.Magnitude
	end

	local alpha = math.clamp((speed - minSpeed) / (maxSpeed - minSpeed), 0, 1)
	sound.Volume = minVol + (maxVol - minVol) * alpha

	-- play + cleanup
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end


-- Convenience function to get the Footsteps SoundGroup for external control
function FootstepEngine.GetSoundGroup()
	return GetFootstepsSoundGroup()
end

-- Raycast-based floor material detection
function FootstepEngine.GetFloorMaterial(Character: Model)
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then return nil end

	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then return nil end

	-- Create raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Character}

	-- Calculate ray origin and direction
	local rayOrigin = HumanoidRootPart.Position
	local rayDirection = Vector3.new(0, -50, 0) -- Ray down 50 studs

	-- Perform the raycast
	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if raycastResult then
		-- Found a surface, return its material
		return raycastResult.Material
	else
		-- No surface found, check humanoid's floor material as fallback
		if Humanoid.FloorMaterial ~= Enum.Material.Air then
			return Humanoid.FloorMaterial
		end
	end

	-- Default to Air if nothing found
	return Enum.Material.Air
end

-- Enhanced function with multiple detection methods
function FootstepEngine.GetSoundId(Character: Model)
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then return nil end

	-- Method 1: Try raycast detection (most accurate)
	local FloorMaterial = FootstepEngine.GetFloorMaterial(Character)

	-- Method 2: Fallback to humanoid's floor material if raycast fails
	if not FloorMaterial or FloorMaterial == Enum.Material.Air then
		FloorMaterial = Humanoid.FloorMaterial
	end

	-- Method 3: Final fallback - check if character is standing on something
	if FloorMaterial == Enum.Material.Air then
		local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
		if HumanoidRootPart then
			-- Check if character is moving slowly (likely on ground)
			local velocity = HumanoidRootPart.AssemblyLinearVelocity
			if velocity.Y > -5 and velocity.Y < 5 then -- Not falling fast
				-- Default to plastic if we think they're on ground but can't detect material
				FloorMaterial = Enum.Material.Plastic
			end
		end
	end

	-- Get sound based on material
	if FloorMaterial and FloorMaterial ~= Enum.Material.Air then
		local MaterialName = FloorMaterial.Name
		local MaterialInTable = Footsteps[MaterialName]
		if MaterialInTable then
			return MaterialInTable
		else
			warn("No material exists for [" .. FloorMaterial.Name .. "]")
			-- Return a default sound instead of nil
			return Footsteps["Plastic"]
		end
	end

	return nil -- No sound for air/falling
end

-- Advanced function with position-specific detection
function FootstepEngine.GetSoundIdAtPosition(Character: Model, Position: Vector3)
	-- Create raycast parameters
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {Character}

	-- Ray from position downward
	local rayOrigin = Position + Vector3.new(0, 1, 0) -- Start slightly above position
	local rayDirection = Vector3.new(0, -10, 0) -- Ray down 10 studs

	-- Perform the raycast
	local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if raycastResult then
		local MaterialName = raycastResult.Material.Name
		local MaterialInTable = Footsteps[MaterialName]
		if MaterialInTable then
			return MaterialInTable
		else
			warn("No material exists for [" .. raycastResult.Material.Name .. "]")
			return Footsteps["Plastic"]
		end
	end

	-- Fallback to regular detection
	return FootstepEngine.GetSoundId(Character)
end

return FootstepEngine