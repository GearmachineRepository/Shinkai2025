--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local EnsembleTypes = require(Server.Ensemble.Types)
local Packets = require(Shared.Networking.Packets)

local Combat = require(Server.Combat)
local ActionExecutor = Combat.ActionExecutor
local ActionRegistry = Combat.ActionRegistry
local InputResolver = Combat.InputResolver
local CombatEvents = Combat.CombatEvents

local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

local PreloadAmount = AnimationTimingCache.PreloadDatabase(AnimationDatabase)
print("[CombatListener] Preloaded " .. PreloadAmount .. " animations")

local function GetEntityFromPlayer(Player: Player): EnsembleTypes.Entity?
	local Character = Player.Character
	if not Character then
		return nil
	end

	return Ensemble.GetEntity(Character)
end

local function GetToolInputData(Entity: EnsembleTypes.Entity): { [string]: any }?
	local ToolComponent = Entity:GetComponent("Tool")
	if not ToolComponent then
		return nil
	end

	local EquippedTool = ToolComponent:GetEquippedTool()
	if not EquippedTool or not EquippedTool.ToolId then
		return nil
	end

	return { ItemId = EquippedTool.ToolId }
end

local function NotifyActionApproved(Player: Player, RawInput: string)
	Packets.ActionApproved:FireClient(Player, RawInput)
end

local function NotifyActionDenied(Player: Player, Reason: string)
	Packets.ActionDenied:FireClient(Player, Reason)
end

local function NotifyActionCompleted(Entity: EnsembleTypes.Entity, ActionName: string)
	if Entity.Player and Entity.Character then
		Packets.ActionCompleted:FireClient(Entity.Player, Entity.Character, ActionName)
	end
end

local function NotifyActionInterrupted(Entity: EnsembleTypes.Entity, Reason: string)
	if Entity.Player and Entity.Character then
		Packets.ActionInterrupted:FireClient(Entity.Player, Entity.Character, Reason)
	end
end

local function HandleWindowCommand(Entity: EnsembleTypes.Entity, WindowType: string): boolean
	local ActiveContext = ActionExecutor.GetActiveContext(Entity)
	if not ActiveContext then
		return false
	end

	if ActiveContext.Metadata.ActionName ~= "Block" then
		return false
	end

	if ActiveContext.CustomData.ActiveWindow then
		return false
	end

	local WindowModule = if WindowType == "PerfectGuard"
		then require(Server.Combat.Actions.PerfectGuard)
		else require(Server.Combat.Actions.Counter)

	local RealCooldownId = WindowType
	local RealCooldown = WindowModule.Cooldown or 10

	if ActionExecutor.IsOnCooldown(Entity, RealCooldownId, RealCooldown) then
		return false
	end

	local SpamCooldownId = WindowType .. "Failure"
	local SpamCooldown = WindowModule.SpamCooldown or 5

	if ActionExecutor.IsOnCooldown(Entity, SpamCooldownId, SpamCooldown) then
		return false
	end

	ActionExecutor.StartCooldown(Entity, SpamCooldownId, SpamCooldown)

	local WindowDuration = WindowModule.WindowDuration or 0.3

	ActiveContext.CustomData.ActiveWindow = WindowType
	ActiveContext.CustomData.WindowStartTime = workspace:GetServerTimeNow()
	Entity.States:SetState(WindowType .. "Window", true)

	Ensemble.Events.Publish(CombatEvents.ParryWindowOpened, {
		Entity = Entity,
		WindowType = WindowType,
		Duration = WindowDuration,
	})

	task.delay(WindowDuration, function()
		if ActiveContext.CustomData.ActiveWindow == WindowType then
			ActiveContext.CustomData.ActiveWindow = nil
			Entity.States:SetState(WindowType .. "Window", false)

			Ensemble.Events.Publish(CombatEvents.ParryWindowClosed, {
				Entity = Entity,
				WindowType = WindowType,
				DidTrigger = false,
			})
		end
	end)

	return true
end

local function HandleActionRequest(Player: Player, RawInput: string, InputData: { [string]: any }?)
	local Entity = GetEntityFromPlayer(Player)
	if not Entity then
		NotifyActionDenied(Player, "NoEntity")
		return
	end

	local ResolvedAction = InputResolver.Resolve(Entity, RawInput)
	if not ResolvedAction then
		NotifyActionDenied(Player, "NoValidAction")
		return
	end

	if ResolvedAction == "PerfectGuard" or ResolvedAction == "Counter" then
		local Success = HandleWindowCommand(Entity, ResolvedAction)
		if Success then
			NotifyActionApproved(Player, RawInput)
		else
			NotifyActionDenied(Player, "WindowFailed")
		end
		return
	end

	local FinalInputData = InputData or {}

	local Definition = ActionRegistry.Get(ResolvedAction)
	if Definition and Definition.ActionType == "Attack" then
		local ToolData = GetToolInputData(Entity)
		if not ToolData then
			NotifyActionDenied(Player, "NoTool")
			return
		end

		for Key, Value in ToolData do
			FinalInputData[Key] = Value
		end
	end

	local Success, Reason = ActionExecutor.Execute(Entity, ResolvedAction, RawInput, FinalInputData)

	if Success then
		NotifyActionApproved(Player, RawInput)
	else
		NotifyActionDenied(Player, Reason or "Failed")
	end
end

local function HandleInterruptRequest(Player: Player, Reason: string)
	local Entity = GetEntityFromPlayer(Player)
	if not Entity then
		NotifyActionDenied(Player, "NoEntity")
		return
	end

	local Interrupted = ActionExecutor.Interrupt(Entity, Reason)
	if not Interrupted then
		NotifyActionDenied(Player, "InterruptFailed")
		return
	end

	NotifyActionInterrupted(Entity, Reason)
end

local function HandleReleaseAction(Player: Player, RawInput: string)
	local Entity = GetEntityFromPlayer(Player)
	if not Entity then
		return
	end

	local ActiveContext = ActionExecutor.GetActiveContext(Entity)
	if not ActiveContext then
		return
	end

	if ActiveContext.RawInput ~= RawInput then
		return
	end

	ActionExecutor.Interrupt(Entity, "Released")
end

local function CleanupEntity(Entity: EnsembleTypes.Entity)
	ActionExecutor.CleanupEntity(Entity)
end

local function Initialize()
	local ActionsFolder = Server.Combat.Actions
	local LoadedCount = ActionRegistry.LoadFolder(ActionsFolder)
	print("[CombatListener] Loaded " .. LoadedCount .. " actions: " .. table.concat(ActionRegistry.GetAllNames(), ", "))

	Ensemble.Events.Subscribe("EntityDestroyed", function(Data: any)
		if Data.Entity then
			CleanupEntity(Data.Entity)
		end
	end)

	Ensemble.Events.Subscribe(CombatEvents.ActionCompleted, function(Data: any)
		if Data.Entity and Data.ActionName then
			NotifyActionCompleted(Data.Entity, Data.ActionName)
		end
	end)

	Ensemble.Events.Subscribe(CombatEvents.ActionInterrupted, function(Data: any)
		if Data.Entity and Data.Reason then
			NotifyActionInterrupted(Data.Entity, Data.Reason)
		end
	end)
end

Packets.PerformAction.OnServerEvent:Connect(function(Player: Player, RawInput: string, InputData: any?)
	HandleActionRequest(Player, RawInput, InputData)
end)

Packets.ReleaseAction.OnServerEvent:Connect(function(Player: Player, RawInput: string)
	HandleReleaseAction(Player, RawInput)
end)

Packets.InterruptAction.OnServerEvent:Connect(function(Player: Player, Reason: string)
	HandleInterruptRequest(Player, Reason)
end)

Initialize()