--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local ArchTypes = require(Server.Ensemble.Types)

local PlayerDataTemplate = require(Shared.Configurations.Data.PlayerDataTemplate)
local DataModule = require(Server.Game.Data.DataModule)

local CombatValidationConfig = require(Shared.Configurations.CombatValidationConfig)

local StatConfig = require(Server.Game.Configs.StatConfig)
local EventConfig = require(Server.Game.Configs.EventConfig)

Ensemble.Init({
	Components = Server.Game.Components,
	Hooks = Server.Game.Hooks,

	Configs = {
		States = CombatValidationConfig.GetStateConfig(),
		Stats = StatConfig,
		Events = EventConfig,
	},

	Archetypes = {
		Player = { "Stamina", "Hunger", "Training", "Movement", "Inventory", "StateHandler", "Tool", "BodyFatigue", "BodyScaling", "Sweat", "StatusEffect", "Damage", "PositionHistory" },
		Entity = { "Movement", "Combat", "Damage", "StatusEffect", "StateHandler", "NpcCombat", "PositionHistory" },
	},
})

local Assets = ReplicatedStorage:WaitForChild("Assets")
local EntityAssets = Assets:WaitForChild("Entity")
local CharacterTemplate = EntityAssets:WaitForChild("Character")

local PlayerMaids: { [Player]: ArchTypes.Maid } = {}
local PlayerCharacterConnections: { [Player]: RBXScriptConnection } = {}

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

local function CleanupOldCharacter(Player: Player)
	local OldCharacter = Player.Character
	if OldCharacter then
		Ensemble.DestroyEntity(OldCharacter)
	end
end

local function SpawnCharacter(Player: Player, PlayerData: any)
	CleanupOldCharacter(Player)

	local Character = CreateCustomCharacter(Player)
	local SpawnCFrame = GetSpawnLocation()

	Character:PivotTo(SpawnCFrame)
	Player.Character = Character
	Character.Parent = workspace.Characters

	CollectionService:AddTag(Character, "Character")
	CloneStarterScripts(Character)

	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid
	if not Humanoid then
		warn("Failed to find Humanoid for", Player.Name)
		return
	end

	local Entity = Ensemble.CreateEntity(Character, {
		Player = Player,
		Data = PlayerData,
	})
		:WithArchetype("Player")
		:WithHooks(PlayerData.Hooks)
		:Build()

	if not Entity then
		warn("Failed to create entity for", Player.Name)
		return
	end

	task.delay(2, function()
		local Inventory = Entity:GetComponent("Inventory")
		if not Inventory then
			return
		end

		Inventory:AddItemToHotbar(1, "Karate", 1)
	end)

	Humanoid.Died:Once(function()
		task.wait(3)
		if not Player.Parent then
			return
		end
		SpawnCharacter(Player, PlayerData)
	end)

	if PlayerCharacterConnections[Player] then
		PlayerCharacterConnections[Player]:Disconnect()
	end

	PlayerCharacterConnections[Player] = Character.AncestryChanged:Connect(function(_, NewParent)
		if not NewParent then
			Ensemble.DestroyEntity(Character)
			if PlayerCharacterConnections[Player] then
				PlayerCharacterConnections[Player]:Disconnect()
				PlayerCharacterConnections[Player] = nil
			end
		end
	end)
end

Players.PlayerAdded:Connect(function(Player: Player)
	local PlayerMaid = Ensemble.Maid.new()
	PlayerMaids[Player] = PlayerMaid

	local PlayerData = DataModule.LoadData(Player)
	if not PlayerData then
		PlayerData = table.clone(PlayerDataTemplate)
	end

	SpawnCharacter(Player, PlayerData)
end)

Players.PlayerRemoving:Connect(function(Player: Player)
	if PlayerCharacterConnections[Player] then
		PlayerCharacterConnections[Player]:Disconnect()
		PlayerCharacterConnections[Player] = nil
	end

	local PlayerMaid = PlayerMaids[Player]
	if PlayerMaid then
		PlayerMaid:DoCleaning()
		PlayerMaids[Player] = nil
	end

	local Character = Player.Character
	if Character then
		Ensemble.DestroyEntity(Character)
		Character:Destroy()
	end
end)