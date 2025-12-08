--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)

local INTERACTABLES_FOLDER = ServerScriptService.Server:WaitForChild("Interactables")

local function HandleInteraction(Player: Player, InteractableObject: Instance, IsStopAction: boolean)
	if not InteractableObject or not InteractableObject:IsA("Model") then
		warn("Invalid interactable object from player:", Player.Name)
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: Part
	local InteractablePrimaryPart = InteractableObject.PrimaryPart

	if not HumanoidRootPart or not InteractablePrimaryPart then
		return
	end

	local IsActiveForPlayer = InteractableObject:GetAttribute("ActiveFor") == Player.UserId
	local MaxDistance = if IsActiveForPlayer then 15 else 12
	local Distance = (HumanoidRootPart.Position - InteractablePrimaryPart.Position).Magnitude

	if Distance > MaxDistance then
		warn("Player too far from interactable:", Player.Name)
		return
	end

	local InteractableType = InteractableObject:GetAttribute("InteractableType") or InteractableObject.Name
	local InteractableModule = INTERACTABLES_FOLDER:FindFirstChild(InteractableType)

	if not InteractableModule or not InteractableModule:IsA("ModuleScript") then
		warn("No interactable module found for type:", InteractableType)
		return
	end

	local Success, ModuleOrError = pcall(require, InteractableModule)
	if not Success then
		warn("Failed to load interactable module:", InteractableType, ModuleOrError)
		return
	end

	local InteractableHandler = ModuleOrError

	if IsStopAction then
		if typeof(InteractableHandler.OnStopInteract) == "function" then
			InteractableHandler.OnStopInteract(Player, InteractableObject)
		end
	else
		if typeof(InteractableHandler.OnInteract) == "function" then
			InteractableHandler.OnInteract(Player, InteractableObject)
		end
	end
end

Packets.InteractRequest.OnServerEvent:Connect(HandleInteraction)