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

-----------begin feint logic
local REQUIRE_UNPREDICTABLE_FOR_FEINT = true
local UNPREDICTABLE_MAX_CHARGES = 2
local UNPREDICTABLE_COOLDOWN_SECONDS = 30
local UNPREDICTABLE_COOLDOWN_ID = "Unpredictable"

local EntityFeintCharges: { [Entity]: number } = {}
local EntityFeintCooldowns: { [Entity]: number } = {}

local function HasUnpredictable(Entity: Entity): boolean
	local HookComponent = Entity:GetComponent("Hooks")
	return HookComponent ~= nil and HookComponent:HasHook("Unpredictable")
end

local function IsFeintOnCooldown(Entity: Entity): boolean
	local CooldownEnd = EntityFeintCooldowns[Entity]
	if not CooldownEnd then
		return false
	end
	return workspace:GetServerTimeNow() < CooldownEnd
end

local function ConsumeFeintCharge(Entity: Entity)
	local CurrentCharges = EntityFeintCharges[Entity] or 0
	CurrentCharges += 1
	EntityFeintCharges[Entity] = CurrentCharges

	if CurrentCharges >= UNPREDICTABLE_MAX_CHARGES then
		local CooldownEnd = workspace:GetServerTimeNow() + UNPREDICTABLE_COOLDOWN_SECONDS
		EntityFeintCooldowns[Entity] = CooldownEnd
		EntityFeintCharges[Entity] = 0

		if Entity.Player then
			Packets.StartCooldown:FireClient(
				Entity.Player,
				UNPREDICTABLE_COOLDOWN_ID,
				workspace:GetServerTimeNow(),
				UNPREDICTABLE_COOLDOWN_SECONDS
			)
		end
	end
end

local function CanEntityFeint(Entity: Entity): boolean
	if not REQUIRE_UNPREDICTABLE_FOR_FEINT then
		return true
	end

	if not HasUnpredictable(Entity) then
		return false
	end

	if IsFeintOnCooldown(Entity) then
		return false
	end

	return true
end
---------- end feint logic

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

local function NotifyActionInterrupted(Entity: Entity, ActionName: string, Reason: string)
	if Entity.Player and Entity.Character then
		Packets.ActionInterrupted:FireClient(Entity.Player, Entity.Character, ActionName, Reason)
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

local function HandleWindowCommand(Entity: Entity, WindowType: string, InputTimestamp: number?): boolean
	return Combat.OpenWindow(Entity, WindowType, InputTimestamp)
end

local function HandleActionRequest(Player: Player, RawInput: string, InputTimestamp: number?, InputData: { [string]: any }?)
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

	local FinalInputData = InputData or {} :: { [string]: any }
	FinalInputData.InputTimestamp = InputTimestamp

	if ResolvedAction == "Dodge" then
		local ActiveContext = Combat.ActionExecutor.GetActiveContext(Entity)
		if ActiveContext and ActiveContext.Metadata.ActionName == "Block" then
			local Success, Reason = Combat.ActionExecutor.ExecuteParallel(Entity, ResolvedAction, RawInput, InputData)
			if Success then
				NotifyActionApproved(Player, RawInput)
			else
				NotifyActionDenied(Player, Reason or "Failed")
			end
			return
		end
	end

	if ResolvedAction == "Feint" and REQUIRE_UNPREDICTABLE_FOR_FEINT then
		if not HasUnpredictable(Entity) then
			NotifyActionDenied(Player, "RequiresUnpredictable")
			return
		end
	end

	if ResolvedAction == "Feint" then
		if not CanEntityFeint(Entity) then
			NotifyActionDenied(Player, "FeintUnavailable")
			return
		end
	end

	if ResolvedAction == "PerfectGuard" or ResolvedAction == "Counter" then
		local Success = HandleWindowCommand(Entity, ResolvedAction, InputTimestamp)
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

	Combat.Interrupt(Entity, Reason)
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

Ensemble.Events.Subscribe("ActionCompleted", function(Data: any)
	if Data.Entity and Data.ActionName then
		if Data.Entity.Player and Data.Entity.Character then
			Packets.ActionCompleted:FireClient(Data.Entity.Player, Data.Entity.Character, Data.ActionName)
		end
	end
end)

Ensemble.Events.Subscribe("ActionInterrupted", function(Data: any)
	if Data.Entity and Data.ActionName and Data.Reason then
		NotifyActionInterrupted(Data.Entity, Data.ActionName, Data.Reason)
	end
end)

Ensemble.Events.Subscribe("FeintExecuted", function(Data: any)
	if Data.Entity and REQUIRE_UNPREDICTABLE_FOR_FEINT then
		ConsumeFeintCharge(Data.Entity)
	end
end)

Ensemble.Events.Subscribe("DamageIndicatorTriggered", function(Data: any)
	if not Data.Attacker or not Data.Target or not Data.DamageAmount then
		return
	end

	local AttackerPlayer = Data.Attacker.Player
	if not AttackerPlayer then
		return
	end

	local TargetCharacter = Data.Target.Character
	if not TargetCharacter then
		return
	end

	local HitPosition = Data.HitPosition or TargetCharacter:GetPivot().Position
	local IndicatorType = Data.IndicatorType or "Normal"

	Packets.ShowDamageIndicator:FireClient(
		AttackerPlayer,
		TargetCharacter,
		Data.DamageAmount,
		HitPosition,
		IndicatorType
	)
end)

Packets.PerformAction.OnServerEvent:Connect(HandleActionRequest)
Packets.InterruptAction.OnServerEvent:Connect(HandleInterruptRequest)
Packets.ReleaseAction.OnServerEvent:Connect(HandleReleaseAction)