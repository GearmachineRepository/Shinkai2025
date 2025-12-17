--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local EntityService = require(Server.Core.EntityService)
local EntityUpdateSystem = require(Server.Core.EntityUpdateSystem)
local PlayerDataTemplate = require(Shared.Configurations.Data.PlayerDataTemplate)
local DebugLogger = require(Shared.Debug.DebugLogger)
local DataModule = require(Server.DataModule)
local Maid = require(Shared.General.Maid)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local EntityAssets = Assets:WaitForChild("Entity")
local CharacterTemplate = EntityAssets:WaitForChild("Character")

local PlayerMaids: { [Player]: Maid.MaidSelf } = {}

task.defer(function()
	require(Server.Entity.ComponentInitializer)
end)

print("EntityUpdateSystem loaded:", EntityUpdateSystem)

local function GetSpawnLocation(): CFrame
	local SpawnLocations = {}
	for _, Descendant in workspace:GetDescendants() do
		if Descendant:IsA("SpawnLocation") then
			table.insert(SpawnLocations, Descendant)
		end
	end

	if #SpawnLocations > 0 then
		local RandomSpawn = SpawnLocations[math.random(1, #SpawnLocations)]
		return RandomSpawn.CFrame + Vector3.new(0, 3, 0)
	end

	return CFrame.new(0, 10, 0)
end

local function CreateCustomCharacter(Player: Player): Model
	local NewCharacter = CharacterTemplate:Clone()
	NewCharacter.Name = Player.Name

	local Humanoid = NewCharacter:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid.DisplayName = Player.DisplayName
	end

	return NewCharacter
end

local function CloneStarterScripts(Character: Model)
	local StarterPlayer = game:GetService("StarterPlayer")
	local StarterCharacterScripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")

	if StarterCharacterScripts then
		for _, Object in StarterCharacterScripts:GetChildren() do
			Object:Clone().Parent = Character
		end
	end
end

local function SpawnCharacter(Player: Player, PlayerData: any)
	local Character = CreateCustomCharacter(Player)
	local SpawnCFrame = GetSpawnLocation()

	Character:PivotTo(SpawnCFrame)
	Player.Character = Character
	Character.Parent = workspace

	Character:AddTag("Character")
	CloneStarterScripts(Character)

	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid
	if not Humanoid then
		warn("Failed to find Humanoid for", Player.Name)
		return
	end

	local Entity = EntityService.CreateEntity(Character, Player, PlayerData)
	if not Entity then
		warn("Failed to create entity for", Player.Name)
		return
	end

	Humanoid.Died:Once(function()
		task.wait(3)
		SpawnCharacter(Player, PlayerData)
	end)

	DebugLogger.Info(script.Name, "Loaded character for: ", Player.Name)
end

Players.PlayerAdded:Connect(function(Player: Player)
	local PlayerMaid = Maid.new()
	PlayerMaids[Player] = PlayerMaid

	local PlayerData = DataModule.LoadData(Player)
	if not PlayerData then
		PlayerData = table.clone(PlayerDataTemplate)
	end

	SpawnCharacter(Player, PlayerData)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	local PlayerMaid = PlayerMaids[Player]
	if PlayerMaid then
		PlayerMaid:DoCleaning()
		PlayerMaids[Player] = nil
	end

	if Player.Character then
		EntityService.DestroyEntity(Player.Character)
	end

	DebugLogger.Info(script.Name, "Removed character for: ", Player.Name)
end)
