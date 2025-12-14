--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterController = require(Server.Entity.Core.CharacterController)
local Promise = require(Shared.Packages.Promise)
local Maid = require(Shared.General.Maid)
local ClanData = require(Shared.Configurations.Data.ClanData)
local TraitData = require(Shared.Configurations.Data.TraitData)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local EntityAssets = Assets:WaitForChild("Entity")
local CharacterTemplate = EntityAssets:WaitForChild("Character")

local CharacterLoader = {}
local PlayerMaids: { [Player]: Maid.MaidSelf } = {}
local NPCMaids: { [Model]: Maid.MaidSelf } = {}
local ActivePromises: { [any]: typeof(Promise) } = {}

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

function CharacterLoader.SpawnCharacter(Player: Player, PlayerData)
	return Promise.new(function(Resolve, Reject)
		local Character = CreateCustomCharacter(Player)
		local SpawnCFrame = GetSpawnLocation()

		Character:PivotTo(SpawnCFrame)
		Player.Character = Character
		Character.Parent = workspace

		Character:AddTag("Character")

		CloneStarterScripts(Character)

		local Success, Humanoid = pcall(function()
			return Character:WaitForChild("Humanoid", 5) :: Humanoid
		end)

		if not Success or not Humanoid then
			Reject("Failed to find Humanoid")
			return
		end

		local Controller = CharacterController.new(Character, Player, PlayerData)

		if PlayerData.Hooks and type(PlayerData.Hooks) == "table" then
			for _, HookName in PlayerData.Hooks do
				Controller.HookController:RegisterHook(HookName)
			end
		end

		if PlayerData.Traits and type(PlayerData.Traits) == "table" then
			for _, TraitName in PlayerData.Traits do
				local Trait = TraitData.Definitions[TraitName]
				if Trait and Trait.Hooks then
					for _, HookName in Trait.Hooks do
						Controller.HookController:RegisterHook(HookName)
					end
				end
			end
		end

		if PlayerData.Clan and PlayerData.Clan.ClanName then
			local Clan = ClanData[PlayerData.Clan.ClanName]
			if Clan and Clan.Hooks then
				for _, HookName in Clan.Hooks do
					Controller.HookController:RegisterHook(HookName)
				end
			end
		end

		print("Player spawned:", Player.Name)

		Humanoid.Died:Once(function()
			task.wait(3)
			CharacterLoader.LoadPlayer(Player, PlayerData)
		end)

		Resolve(Controller)
	end)
end

local function TrackEntityPromise(
	Entity: Player | Model,
	PromiseObj: typeof(Promise),
	MaidTable: { [any]: Maid.MaidSelf },
	ActivePromisesTable: { [any]: typeof(Promise) }
)
	local MaidObj = MaidTable[Entity]
	if not MaidObj then
		MaidObj = Maid.new()
		MaidTable[Entity] = MaidObj

		MaidObj:GiveTask(Entity.AncestryChanged:Connect(function(_, Parent)
			if not Parent then
				MaidObj:DoCleaning()
				MaidTable[Entity] = nil
				ActivePromisesTable[Entity] = nil
			end
		end))
	end

	MaidObj:DoCleaning()
	MaidObj:GiveTask(PromiseObj)
	ActivePromisesTable[Entity] = PromiseObj
end

function CharacterLoader.LoadPlayer(Player: Player, PlayerData)
	local LoadPromise = CharacterLoader.SpawnCharacter(Player, PlayerData)
		:andThen(function(Controller)
			print("Character fully loaded for:", Player.Name)
			return Controller
		end)
		:catch(function(Error)
			warn("Failed to load character for", Player.Name, ":", Error)
		end)

	TrackEntityPromise(Player, LoadPromise, PlayerMaids, ActivePromises)
	return LoadPromise
end

function CharacterLoader.LoadNPC(NPCCharacter: Model)
	local LoadPromise = Promise.new(function(Resolve, Reject)
		local Success, Result = pcall(function()
			return CharacterController.new(NPCCharacter, nil)
		end)

		if Success then
			print("NPC loaded:", NPCCharacter.Name)
			Resolve(Result)
		else
			Reject(Result)
		end
	end)

	TrackEntityPromise(NPCCharacter, LoadPromise, NPCMaids, ActivePromises)
	return LoadPromise
end

function CharacterLoader.CleanupPlayer(Player: Player)
	local PlayerMaid = PlayerMaids[Player]
	if PlayerMaid then
		PlayerMaid:DoCleaning()
		PlayerMaids[Player] = nil
	end

	ActivePromises[Player] = nil

	if Player.Character then
		local Controller = CharacterController.Get(Player.Character)
		if Controller then
			Controller:Destroy()
		end
	end
end

function CharacterLoader.CleanupNPC(NPCCharacter: Model)
	local NPCMaid = NPCMaids[NPCCharacter]
	if NPCMaid then
		NPCMaid:DoCleaning()
		NPCMaids[NPCCharacter] = nil
	end

	ActivePromises[NPCCharacter] = nil

	local Controller = CharacterController.Get(NPCCharacter)
	if Controller then
		Controller:Destroy()
	end
end

return CharacterLoader
