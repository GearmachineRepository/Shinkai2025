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
local CooldownSystem = require(Server.Game.Systems.CooldownSystem)

local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

local PreloadAmount = AnimationTimingCache.PreloadDatabase(AnimationDatabase)
warn("Preloaded (" .. PreloadAmount .. ") Animations")

local UNPREDICTABLE_COOLDOWN_ID = "Unpredictable"
local UNPREDICTABLE_MAX_CHARGES = 2
local UNPREDICTABLE_COOLDOWN_DURATION = 30

local EntityCooldowns: { [any]: CooldownSystem.CooldownController } = {}
local EntityFeintCharges: { [any]: number } = {}

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

local function GetCooldownController(Entity: EnsembleTypes.Entity): CooldownSystem.CooldownController
	if not EntityCooldowns[Entity] then
		EntityCooldowns[Entity] = CooldownSystem.new()
	end
	return EntityCooldowns[Entity]
end

local function GetFeintCharges(Entity: EnsembleTypes.Entity): number
	return EntityFeintCharges[Entity] or 0
end

local function ConsumeFeintCharge(Entity: EnsembleTypes.Entity)
	local CurrentCharges = GetFeintCharges(Entity)
	EntityFeintCharges[Entity] = CurrentCharges + 1
end

local function ResetFeintCharges(Entity: EnsembleTypes.Entity)
	EntityFeintCharges[Entity] = 0
end

local function CanUseUnpredictable(Entity: EnsembleTypes.Entity): boolean
	local HookComponent = Entity:GetComponent("Hooks")
	if not HookComponent or not HookComponent:HasHook("Unpredictable") then
		return false
	end

	local Cooldowns = GetCooldownController(Entity)
	if Cooldowns:IsOnCooldown(UNPREDICTABLE_COOLDOWN_ID) then
		return false
	end

	return true
end

local function TryUnpredictableFeint(Entity: EnsembleTypes.Entity): boolean
	if not CanUseUnpredictable(Entity) then
		return false
	end

	local Interrupted = ActionExecutor.Interrupt(Entity, "Feint")
	if not Interrupted then
		return false
	end

	ConsumeFeintCharge(Entity)

	local CurrentCharges = GetFeintCharges(Entity)
	if CurrentCharges >= UNPREDICTABLE_MAX_CHARGES then
		local Cooldowns = GetCooldownController(Entity)
		local StartTime = workspace:GetServerTimeNow()

		Cooldowns:Start(UNPREDICTABLE_COOLDOWN_ID, UNPREDICTABLE_COOLDOWN_DURATION)
		ResetFeintCharges(Entity)

		if Entity.Player then
			Packets.StartCooldown:FireClient(
				Entity.Player,
				UNPREDICTABLE_COOLDOWN_ID,
				StartTime,
				UNPREDICTABLE_COOLDOWN_DURATION
			)
		end
	end

	return true
end

local function CleanupEntity(Entity: EnsembleTypes.Entity)
	if EntityCooldowns[Entity] then
		EntityCooldowns[Entity]:Destroy()
		EntityCooldowns[Entity] = nil
	end
	EntityFeintCharges[Entity] = nil
end

local function Initialize()
	local ActionsFolder = Server.Combat.Actions
	ActionRegistry.LoadFolder(ActionsFolder)

	Ensemble.Events.Subscribe("EntityDestroyed", function(Data: any)
		if Data.Entity then
			CleanupEntity(Data.Entity)
		end
	end)
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
				return
			end
		else
			return
		end
	end

	local Success, Reason = ActionExecutor.Execute(Entity, ActionName, FinalInputData)

	if Success then
		Packets.ActionApproved:FireClient(Player, ActionName)
		return
	end

	if ActionName == "M2" then
		if TryUnpredictableFeint(Entity) then
			Packets.ActionApproved:FireClient(Player, ActionName)
			return
		end
	end

	Packets.ActionDenied:FireClient(Player, Reason or "Failed")
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