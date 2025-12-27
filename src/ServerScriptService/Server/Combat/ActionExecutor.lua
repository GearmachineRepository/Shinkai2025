--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatTypes = require(script.Parent.CombatTypes)
local ActionRegistry = require(script.Parent.ActionRegistry)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
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

local function ApplyItemData(Metadata: ActionMetadata, ItemId: string?)
	if not ItemId then
		return
	end

	local ItemData = ItemDatabase.GetItem(ItemId)
	if not ItemData then
		return
	end

	if ItemData.BaseStats then
		for Key, Value in ItemData.BaseStats do
			Metadata[Key] = Value
		end
	end

	if ItemData.AnimationSet then
		Metadata.AnimationSet = ItemData.AnimationSet
	end
end

local function ResolveAttackData(Entity: CombatTypes.Entity, Metadata: ActionMetadata): { [string]: any }?
	local AnimationSetName = Metadata.AnimationSet or "Karate"
	local ComboCount = ActionExecutor.GetComboCount(Entity)

	local AttackData = AnimationSets.GetAttack(AnimationSetName, ComboCount)
	if not AttackData then
		return nil
	end

	Metadata.BaseDamage = Metadata.BaseDamage or AttackData.Damage
	Metadata.StaminaCost = Metadata.StaminaCost or AttackData.StaminaCost

	if AttackData.Hitbox then
		Metadata.HitboxSize = Metadata.HitboxSize or AttackData.Hitbox.Size
		Metadata.HitboxOffset = Metadata.HitboxOffset or CFrame.new(AttackData.Hitbox.Offset)
	end

	return {
		AttackData = AttackData,
		AnimationSetName = AnimationSetName,
		ComboCount = ComboCount,
	}
end

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
		return false, "AlreadyExecuting"
	end

	local Definition: ActionDefinition?, BaseMetadata: ActionMetadata? = ActionRegistry.GetWithMetadata(ActionName, nil)
	if not Definition or not BaseMetadata then
		return false, "UnknownAction"
	end

	local Metadata: ActionMetadata = table.clone(BaseMetadata)
	local FinalInputData = InputData or {} :: {[string]: any}

	if not FinalInputData or not FinalInputData["ItemId"] then return false, "No ItemId present" end

	ApplyItemData(Metadata, FinalInputData.ItemId)

	local Context = CreateContext(Entity, Metadata, FinalInputData)

	if Definition.ActionType == "Attack" then
		local AttackContext = ResolveAttackData(Entity, Metadata)
		if AttackContext then
			Context.CustomData.AttackData = AttackContext.AttackData
			Context.CustomData.AnimationSetName = AttackContext.AnimationSetName
			Context.CustomData.ComboCount = AttackContext.ComboCount
		end
	end

	Ensemble.Events.Publish("ActionConfiguring", {
		Entity = Entity,
		ActionName = ActionName,
		Metadata = Metadata,
	})

	if Definition.CanExecute then
		local CanExecute, Reason = Definition.CanExecute(Context)
		if not CanExecute then
			return false, Reason or "CannotExecute"
		end
	end

	ActiveContexts[Entity] = Context

	if Definition.OnStart then
		Definition.OnStart(Context)
	end

	Ensemble.Events.Publish("ActionStarted", {
		Entity = Entity,
		ActionName = ActionName,
		Metadata = Metadata,
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
	if not Context or Context.Interrupted or not Context.Metadata then
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
			if (CurrentTime - LastFeintTime) < FeintCooldown then
				return false
			end
		end
	end

	Context.Interrupted = true
	Context.InterruptReason = InterruptReason

	local Definition = ActionRegistry.Get(Context.Metadata.ActionName)
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
	if not Context or Context.Interrupted or not Context.Metadata then
		return
	end

	local Definition = ActionRegistry.Get(Context.Metadata.ActionName)
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
	if not Context or not Context.Metadata then
		return
	end

	local Definition = ActionRegistry.Get(Context.Metadata.ActionName)
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

	EntityComboCounts[Entity] = (CurrentCombo % ComboLength) + 1
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

	local Elapsed = workspace:GetServerTimeNow() - LastFeintTime
	return math.max(0, FeintCooldownDuration - Elapsed)
end

function ActionExecutor.IsFeintOnCooldown(Entity: CombatTypes.Entity, FeintCooldownDuration: number): boolean
	return ActionExecutor.GetFeintCooldownRemaining(Entity, FeintCooldownDuration) > 0
end

return ActionExecutor