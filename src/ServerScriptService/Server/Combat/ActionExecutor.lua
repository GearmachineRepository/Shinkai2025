--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.CombatTypes)
local ActionRegistry = require(script.Parent.ActionRegistry)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local Packets = require(Shared.Networking.Packets)

type ActionContext = CombatTypes.ActionContext
type ActionDefinition = CombatTypes.ActionDefinition
type ActionMetadata = CombatTypes.ActionMetadata

local ActionExecutor = {}

local ActiveContexts: { [any]: ActionContext } = {}
local EntityComboCounts: { [any]: number } = {}
local EntityComboTimers: { [any]: number } = {}
local EntityFeintCooldowns: { [any]: number } = {}

local COMBO_RESET_TIME = 2.0
local FEINT_COOLDOWN_ID = "Feint"

local function CreateContext(Entity: CombatTypes.Entity, Metadata: ActionMetadata, InputData: any?): ActionContext
	return {
		Entity = Entity,
		InputData = InputData or {},
		Metadata = Metadata,
		StartTime = workspace:GetServerTimeNow(),
		Interrupted = false,
		InterruptReason = nil,
		CustomData = {},
	}
end

function ActionExecutor.Execute(
	Entity: CombatTypes.Entity,
	ActionName: string,
	InputData: { [string]: any }?
): (boolean, string?)

	if ActiveContexts[Entity] ~= nil then
		return false, "Already executing"
	end

	Entity.States:SetState("Attacking", true)

	local Definition: ActionDefinition?, Metadata: ActionMetadata? = ActionRegistry.GetWithMetadata(ActionName, nil)

	if not Definition or not Metadata then
		return false, "Unknown action"
	end

	local Context = CreateContext(Entity, Metadata, InputData)

	if Definition.CanExecute then
		local CanExecute: boolean, Reason: string? = Definition.CanExecute(Context)
		if not CanExecute then
			return false, Reason or "Cannot execute"
		end
	end

	local ModifiedMetadata: ActionMetadata = table.clone(Metadata)

	Ensemble.Events.Publish("ActionConfiguring", {
		Entity = Entity,
		ActionName = ActionName,
		Metadata = ModifiedMetadata,
	})

	Context.Metadata = ModifiedMetadata
	ActiveContexts[Entity] = Context

	if Definition.OnStart then
		Definition.OnStart(Context)
	end

	Ensemble.Events.Publish("ActionStarted", {
		Entity = Entity,
		ActionName = ActionName,
		Metadata = ModifiedMetadata,
		Context = Context,
	})

	task.spawn(function()
		Definition.OnExecute(Context)

		if not Context.Interrupted then
			ActionExecutor.Complete(Entity)
		end
	end)

	return true, nil
end

function ActionExecutor.Interrupt(Entity: CombatTypes.Entity, Reason: string?): boolean
	local Context = ActiveContexts[Entity]
	if not Context then
		return false
	end

	if Context.Interrupted then
		return false
	end

	if not Context.Metadata then
		return false
	end

	local InterruptReason = Reason or "Unknown"

	if InterruptReason == "Feint" then
		if not Context.CustomData.CanFeint or not Context.Metadata.Feintable then
			return false
		end

		local CurrentTime = workspace:GetServerTimeNow()
		local LastFeintTime = EntityFeintCooldowns[Entity]
		local FeintCooldown = Context.Metadata.FeintCooldown or 0

		if LastFeintTime and FeintCooldown > 0 then
			local TimeSinceFeint = CurrentTime - LastFeintTime
			if TimeSinceFeint < FeintCooldown then
				return false
			end
		end
	end

	Context.Interrupted = true
	Context.InterruptReason = InterruptReason

	local Definition: ActionDefinition? = ActionRegistry.Get(Context.Metadata.ActionName)

	if Definition and Definition.OnInterrupt then
		Definition.OnInterrupt(Context)
	end

	Ensemble.Events.Publish("ActionInterrupted", {
		Entity = Entity,
		ActionName = Context.Metadata.ActionName,
		Reason = InterruptReason,
		Context = Context,
	})

	if InterruptReason == "Feint" then
		local FeintCooldown = Context.Metadata.FeintCooldown or 0
		local CurrentTime = workspace:GetServerTimeNow()

		if FeintCooldown > 0 then
			EntityFeintCooldowns[Entity] = CurrentTime

			if Entity.Player then
				Packets.StartCooldown:FireClient(Entity.Player, FEINT_COOLDOWN_ID, CurrentTime, FeintCooldown)
			end
		end

		if Context.Metadata.FeintEndlag then
			task.wait(Context.Metadata.FeintEndlag)
		end
	else
		EntityComboCounts[Entity] = nil
		EntityComboTimers[Entity] = nil
	end

	ActionExecutor.Cleanup(Entity)

	return true
end

function ActionExecutor.Complete(Entity: CombatTypes.Entity)
	local Context = ActiveContexts[Entity]
	if not Context then
		return
	end

	if Context.Interrupted then
		return
	end

	if not Context.Metadata then
		return
	end

	local Definition: ActionDefinition? = ActionRegistry.Get(Context.Metadata.ActionName)

	if Definition and Definition.OnComplete then
		Definition.OnComplete(Context)
	end

	Ensemble.Events.Publish("ActionCompleted", {
		Entity = Entity,
		ActionName = Context.Metadata.ActionName,
		Context = Context,
	})

	ActionExecutor.Cleanup(Entity)
end

function ActionExecutor.Cleanup(Entity: CombatTypes.Entity)
	local Context = ActiveContexts[Entity]
	if not Context then
		return
	end

	if not Context.Metadata then
		return
	end

	local Definition: ActionDefinition? = ActionRegistry.Get(Context.Metadata.ActionName)

	if Definition and Definition.OnCleanup then
		Definition.OnCleanup(Context)
	end

	Entity.States:SetState("Attacking", false)

	ActiveContexts[Entity] = nil
end

function ActionExecutor.GetActiveContext(Entity: CombatTypes.Entity): ActionContext?
	return ActiveContexts[Entity]
end

function ActionExecutor.IsExecuting(Entity: CombatTypes.Entity): boolean
	return ActiveContexts[Entity] ~= nil
end

function ActionExecutor.GetComboCount(Entity: CombatTypes.Entity): number
	local CurrentTime = os.clock()
	local LastComboTime = EntityComboTimers[Entity]

	if LastComboTime and (CurrentTime - LastComboTime) > COMBO_RESET_TIME then
		EntityComboCounts[Entity] = nil
		EntityComboTimers[Entity] = nil
		return 1
	end

	return EntityComboCounts[Entity] or 1
end

function ActionExecutor.IncrementCombo(Entity: CombatTypes.Entity, AnimationSetName: string?)
	local CurrentCombo = ActionExecutor.GetComboCount(Entity)
	local SetName = AnimationSetName or "Karate"
	local ComboLength = AnimationSets.GetComboLength(SetName)

	local NextCombo = (CurrentCombo % ComboLength) + 1

	EntityComboCounts[Entity] = NextCombo
	EntityComboTimers[Entity] = os.clock()
end

function ActionExecutor.ResetCombo(Entity: CombatTypes.Entity)
	EntityComboCounts[Entity] = nil
	EntityComboTimers[Entity] = nil
end

function ActionExecutor.GetFeintCooldownRemaining(Entity: CombatTypes.Entity, FeintCooldownDuration: number): number
	local LastFeintTime = EntityFeintCooldowns[Entity]
	if not LastFeintTime then
		return 0
	end

	local CurrentTime = workspace:GetServerTimeNow()
	local Elapsed = CurrentTime - LastFeintTime
	return math.max(0, FeintCooldownDuration - Elapsed)
end

function ActionExecutor.IsFeintOnCooldown(Entity: CombatTypes.Entity, FeintCooldownDuration: number): boolean
	return ActionExecutor.GetFeintCooldownRemaining(Entity, FeintCooldownDuration) > 0
end

return ActionExecutor