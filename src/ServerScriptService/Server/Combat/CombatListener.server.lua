--!strict
-- Server/Combat/CombatListener.server.lua

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

for _, AnimationId in pairs(AnimationDatabase) do
	AnimationTimingCache.PreloadAnimation(AnimationId)
end

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

	-- If the player tries to start any action while one is running, interrupt the old one first.
	-- if ActionExecutor.IsExecuting(Entity) then
	-- 	ActionExecutor.Interrupt(Entity, "Replaced")
	-- end

	local Success, Reason = ActionExecutor.Execute(Entity, ActionName, InputData)

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
