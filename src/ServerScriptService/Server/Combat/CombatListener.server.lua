--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local EnsembleTypes = require(Server.Ensemble.Types)
local Packets = require(Shared.Networking.Packets)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local ActionRegistry = require(Server.Combat.ActionRegistry)

local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

local PreloadAmount = AnimationTimingCache.PreloadDatabase(AnimationDatabase)
warn("Preloaded (" .. PreloadAmount .. ") Animations")

local FallBackM1 = "Karate"

local function GetEntityFromPlayer(Player: Player): EnsembleTypes.Entity?
	local Character = Player.Character
	if not Character then
		return nil
	end

	local Entity = Ensemble.GetEntity(Character)
	if not Entity then
		return nil
	end

	return Entity
end

local function Initialize()
	local ActionsFolder = Server.Combat.Actions
	ActionRegistry.LoadFolder(ActionsFolder)
end

Packets.PerformAction.OnServerEvent:Connect(function(Player: Player, ActionName: string, InputData: any?)
	local Entity = GetEntityFromPlayer(Player)
	if not Entity then
		Packets.ActionDenied:FireClient(Player, "No entity")
		return
	end

	local FinalInputData = InputData or {}

	if ActionName == "M1" then
		local ToolComponent = Entity:GetComponent("Tool")
		if ToolComponent then
			local EquippedTool = ToolComponent:GetEquippedTool()
			if EquippedTool and EquippedTool.ToolId then
				FinalInputData.ItemId = EquippedTool.ToolId
			else
				FinalInputData.ItemId = FallBackM1
			end
		else
			FinalInputData.ItemId = FallBackM1
		end
	end

	local Success, Reason = ActionExecutor.Execute(Entity, ActionName, FinalInputData)

	if Success then
		Packets.ActionApproved:FireClient(Player, ActionName)
	else
		if ActionName == "M2" then
			local Interrupted = ActionExecutor.Interrupt(Entity, "Feint")
			if not Interrupted then
				return
			end
		else
			Packets.ActionDenied:FireClient(Player, Reason or "Failed")
		end
	end
end)

Packets.InterruptAction.OnServerEvent:Connect(function(Player: Player, Reason: string)
	local Character = Player.Character
	if not Character then
		Packets.ActionDenied:FireClient(Player, "No character")
		return
	end

	local Entity = Ensemble.GetEntity(Character)
	if not Entity then
		Packets.ActionDenied:FireClient(Player, "No entity")
		return
	end

	local Interrupted = ActionExecutor.Interrupt(Entity, "Feint")
	if not Interrupted then
		return
	end

	Packets.ActionInterrupted:FireClient(Player, Character, Reason)
end)

Initialize()