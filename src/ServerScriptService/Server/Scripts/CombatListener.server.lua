--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Combat = require(Server.Combat)
local Ensemble = require(Server.Ensemble)
local Packets = require(Shared.Networking.Packets)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

Combat.Init({
	ActionsFolder = Server.Combat.Actions,
	AnimationDatabase = AnimationDatabase
})

type Entity = Combat.Entity

local function GetEntityFromPlayer(Player: Player): Entity?
	local Character = Player.Character
	if not Character then
		return nil
	end
	return Ensemble.GetEntity(Character)
end

local function NotifyActionApproved(Player: Player, RawInput: string)
	Packets.ActionApproved:FireClient(Player, RawInput)
end

local function NotifyActionDenied(Player: Player, Reason: string)
	Packets.ActionDenied:FireClient(Player, Reason)
end

local function NotifyActionInterrupted(Entity: Entity, Reason: string)
	if Entity.Player then
		Packets.ActionInterrupted:FireClient(Entity.Player, Entity.Character, Reason)
	end
end

local function GetToolInputData(Entity: Entity): { [string]: any }?
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

local function HandleWindowCommand(Entity: Entity, WindowType: string): boolean
	return Combat.OpenWindow(Entity, WindowType)
end

local function HandleActionRequest(Player: Player, RawInput: string, InputData: { [string]: any }?)
	local Entity = GetEntityFromPlayer(Player)
	if not Entity then
		NotifyActionDenied(Player, "NoEntity")
		return
	end

	local ResolvedAction = Combat.ResolveInput(Entity, RawInput)
	if not ResolvedAction then
		NotifyActionDenied(Player, "NoValidAction")
		return
	end

	if ResolvedAction == "PerfectGuard" or ResolvedAction == "Counter" then
		local Success = HandleWindowCommand(Entity, ResolvedAction)
		if Success then

			Ensemble.Events.Publish(ResolvedAction .. "Initiated", {
				Entity = Entity,
				ActionName = ResolvedAction,
			})

			NotifyActionApproved(Player, RawInput)
		else
			NotifyActionDenied(Player, "WindowFailed")
		end
		return
	end

	local FinalInputData = InputData or {}

	local Definition = Combat.ActionRegistry.Get(ResolvedAction)
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

	local Success, Reason = Combat.ActionExecutor.Execute(Entity, ResolvedAction, RawInput, FinalInputData)

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

	local Interrupted = Combat.Interrupt(Entity, Reason)
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

	local ActiveContext = Combat.GetActiveContext(Entity)
	if not ActiveContext then
		return
	end

	local ContextRawInput = ActiveContext.RawInput
	local ActionName = ActiveContext.Metadata and ActiveContext.Metadata.ActionName

	if ContextRawInput then
		if ContextRawInput ~= RawInput then
			return
		end
	elseif ActionName == "Block" and RawInput ~= "Block" then
		return
	end

	Combat.Interrupt(Entity, "Released")
end

Packets.PerformAction.OnServerEvent:Connect(HandleActionRequest)
Packets.InterruptAction.OnServerEvent:Connect(HandleInterruptRequest)
Packets.ReleaseAction.OnServerEvent:Connect(HandleReleaseAction)