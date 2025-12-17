--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)
local Formulas = require(ReplicatedStorage.Shared.General.Formulas)
local DebugLogger = require(ReplicatedStorage.Shared.Debug.DebugLogger)

local INTERACTABLES_FOLDER = ServerScriptService.Server:WaitForChild("Interactables")
local INTERACTION_DISTANCE = 12
local ACTIVE_INTERACTION_DISTANCE = 15

local LoadedModules: { [string]: any } = {}

local function LoadInteractableModule(InteractableType: string): any?
	if LoadedModules[InteractableType] then
		return LoadedModules[InteractableType]
	end

	local InteractableModule = INTERACTABLES_FOLDER:FindFirstChild(InteractableType)

	if not InteractableModule or not InteractableModule:IsA("ModuleScript") then
		DebugLogger.Warning("InteractionServer", "No module found for type: %s", InteractableType)
		return nil
	end

	local Success, Result = pcall(require, InteractableModule)
	if not Success then
		DebugLogger.Error("InteractionServer", "Failed to load module %s: %s", InteractableType, Result)
		return nil
	end

	LoadedModules[InteractableType] = Result
	return Result
end

local function ValidateInteractable(InteractableObject: Instance): (boolean, string?)
	if not InteractableObject or not InteractableObject:IsA("Model") then
		return false, "Invalid interactable object"
	end

	if not InteractableObject.PrimaryPart then
		return false, "Interactable has no PrimaryPart"
	end

	return true
end

local function ValidatePlayer(Player: Player): (boolean, string?)
	local Character = Player.Character
	if not Character then
		return false, "Player has no character"
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: Part?
	if not HumanoidRootPart then
		return false, "Character has no HumanoidRootPart"
	end

	return true
end

local function CheckDistance(Player: Player, InteractableObject: Model): (boolean, string?)
	local Character = Player.Character
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: Part
	local InteractablePrimaryPart = InteractableObject.PrimaryPart

	local IsActiveForPlayer = InteractableObject:GetAttribute("ActiveFor") == Player.UserId
	local MaxDistance = if IsActiveForPlayer then ACTIVE_INTERACTION_DISTANCE else INTERACTION_DISTANCE

	local Distance = Formulas.Distance(HumanoidRootPart.Position, InteractablePrimaryPart.Position)

	if Distance > MaxDistance then
		return false, string.format("Too far: %.1f studs (max: %d)", Distance, MaxDistance)
	end

	return true
end

local function HandleInteraction(Player: Player, InteractableObject: Instance, IsStopAction: boolean)
	local IsValidInteractable, InteractableError = ValidateInteractable(InteractableObject)
	if not IsValidInteractable then
		DebugLogger.Warning("InteractionServer", "Invalid interactable from %s: %s", Player.Name, InteractableError)
		return
	end

	local IsValidPlayer, PlayerError = ValidatePlayer(Player)
	if not IsValidPlayer then
		DebugLogger.Warning("InteractionServer", "Invalid player state %s: %s", Player.Name, PlayerError)
		return
	end

	local IsInRange, DistanceError = CheckDistance(Player, InteractableObject :: Model)
	if not IsInRange then
		DebugLogger.Info("InteractionServer", "%s out of range: %s", Player.Name, DistanceError)
		return
	end

	local InteractableType = InteractableObject:GetAttribute("InteractableType") or InteractableObject.Name
	local InteractableHandler = LoadInteractableModule(InteractableType)

	if not InteractableHandler then
		return
	end

	if IsStopAction then
		if typeof(InteractableHandler.OnStopInteract) == "function" then
			local Success, Error = pcall(InteractableHandler.OnStopInteract, Player, InteractableObject)
			if not Success then
				DebugLogger.Error("InteractionServer", "OnStopInteract failed for %s: %s", InteractableType, Error)
			end
		end
	else
		if typeof(InteractableHandler.OnInteract) == "function" then
			local Success, Error = pcall(InteractableHandler.OnInteract, Player, InteractableObject)
			if not Success then
				DebugLogger.Error("InteractionServer", "OnInteract failed for %s: %s", InteractableType, Error)
			end
		end
	end
end

Packets.InteractRequest.OnServerEvent:Connect(HandleInteraction)
