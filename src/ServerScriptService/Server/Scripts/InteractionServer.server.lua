--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)
local Formulas = require(ReplicatedStorage.Shared.General.Formulas)
local DebugLogger = require(ReplicatedStorage.Shared.Debug.DebugLogger)

local INTERACTABLES_FOLDER = ServerScriptService.Server.Game:WaitForChild("Interactables")
local INTERACTION_DISTANCE = 12
local ACTIVE_INTERACTION_DISTANCE = 15

local LoadedModules: { [string]: any } = {}

local function LoadInteractableModule(InteractableType: string): any?
	if LoadedModules[InteractableType] then
		return LoadedModules[InteractableType]
	end

	local InteractableModule = INTERACTABLES_FOLDER:FindFirstChild(InteractableType)

	if not InteractableModule or not InteractableModule:IsA("ModuleScript") then
		return nil
	end

	local Success, Result = pcall(require, InteractableModule)
	if not Success then
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
	local IsValidInteractable, _InteractableError = ValidateInteractable(InteractableObject)
	if not IsValidInteractable then
		return
	end

	local IsValidPlayer, _PlayerError = ValidatePlayer(Player)
	if not IsValidPlayer then
		return
	end

	local IsInRange, _DistanceError = CheckDistance(Player, InteractableObject :: Model)
	if not IsInRange then
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
