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

local function BuildMetadata(
	ActionName: string,
	ItemId: string,
	ComboCount: number
): ActionMetadata?
	local ItemData = ItemDatabase.GetItem(ItemId)
	if not ItemData then
		return nil
	end

	local AnimationSetName = ItemData.AnimationSet
	local SetMetadata = AnimationSets.GetMetadata(AnimationSetName)
	local AttackData = AnimationSets.GetAttack(AnimationSetName, ActionName, ComboCount)

	if not AttackData then
		return nil
	end

	local StatModifiers = ItemData.StatModifiers

	local FinalDamage = AttackData.Damage
	local FinalStaminaCost = AttackData.StaminaCost

	if StatModifiers then
		if StatModifiers.DamageMultiplier then
			FinalDamage = FinalDamage * StatModifiers.DamageMultiplier
		end
		if StatModifiers.StaminaCostMultiplier then
			FinalStaminaCost = FinalStaminaCost * StatModifiers.StaminaCostMultiplier
		end
	end

	local Metadata: ActionMetadata = {
		ActionName = ActionName,
		AnimationSet = AnimationSetName,
		AnimationId = AttackData.AnimationId,
		ComboCount = ComboCount,

		Damage = FinalDamage,
		StaminaCost = FinalStaminaCost,
		HitStun = AttackData.HitStun,

		HitboxSize = AttackData.Hitbox.Size,
		HitboxOffset = AttackData.Hitbox.Offset,

		Feintable = SetMetadata.Feintable,
		FeintEndlag = SetMetadata.FeintEndlag,
		FeintCooldown = SetMetadata.FeintCooldown,
		ComboEndlag = SetMetadata.ComboEndlag,
		ComboResetTime = SetMetadata.ComboResetTime,
		StaminaCostHitReduction = SetMetadata.StaminaCostHitReduction,

		FallbackHitStart = SetMetadata.FallbackTimings.HitStart,
		FallbackHitEnd = SetMetadata.FallbackTimings.HitEnd,
		FallbackLength = SetMetadata.FallbackTimings.Length,
	}

	return Metadata
end

function ActionExecutor.Execute(
	Entity: CombatTypes.Entity,
	ActionName: string,
	InputData: { [string]: any }?
): (boolean, string?)
	if ActiveContexts[Entity] ~= nil then
		return false, "AlreadyExecuting"
	end

	local Definition = ActionRegistry.Get(ActionName)
	if not Definition then
		return false, "UnknownAction"
	end

	if not InputData then return false, "NoInputData" end
	local ItemId = InputData.ItemId

	if not ItemId then
		return false, "NoItemId"
	end

	local ComboCount = ActionExecutor.GetComboCount(Entity)
	local Metadata = BuildMetadata(ActionName, ItemId, ComboCount)

	if not Metadata then
		return false, "FailedToBuildMetadata"
	end

	local Context: ActionContext = {
		Entity = Entity,
		InputData = InputData,
		Metadata = Metadata,
		StartTime = workspace:GetServerTimeNow(),
		Interrupted = false,
		InterruptReason = nil,
		CustomData = {},
	}

	Ensemble.Events.Publish("ActionConfiguring", {
		Entity = Entity,
		ActionName = ActionName,
		Context = Context,
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

	Context.Interrupted = true
	Context.InterruptReason = Reason

	local FeintCooldown = Context.Metadata.FeintCooldown or 0
	local CurrentTime = workspace:GetServerTimeNow()

	if FeintCooldown > 0 then
		EntityFeintCooldowns[Entity] = CurrentTime

		if Entity.Player then
			Packets.StartCooldown:FireClient(Entity.Player, FEINT_COOLDOWN_ID, CurrentTime, FeintCooldown)
		end
	end

	local Definition = ActionRegistry.Get(Context.Metadata.ActionName)
	if Definition and Definition.OnInterrupt then
		Definition.OnInterrupt(Context)
	end

	ActionExecutor.Cleanup(Entity)

	return true
end

function ActionExecutor.Complete(Entity: CombatTypes.Entity)
	local Context = ActiveContexts[Entity]
	if not Context then
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
	if not Context then
		return
	end

	local Definition = ActionRegistry.Get(Context.Metadata.ActionName)
	if Definition and Definition.OnCleanup then
		Definition.OnCleanup(Context)
	end

	ActiveContexts[Entity] = nil
end

function ActionExecutor.GetActiveContext(Entity: CombatTypes.Entity): ActionContext?
	return ActiveContexts[Entity]
end

function ActionExecutor.IsExecuting(Entity: CombatTypes.Entity): boolean
	return ActiveContexts[Entity] ~= nil
end

function ActionExecutor.GetComboCount(Entity: CombatTypes.Entity): number
	local CurrentTime = workspace:GetServerTimeNow()
	local LastComboTime = EntityComboTimers[Entity]

	if not LastComboTime or (CurrentTime - LastComboTime) > COMBO_RESET_TIME then
		EntityComboCounts[Entity] = 1
		return 1
	end

	return EntityComboCounts[Entity] or 1
end

function ActionExecutor.SetCombo(Entity: CombatTypes.Entity, CurrentCombo: number, MaxCombo: number)
	local NextCombo = CurrentCombo + 1
	if NextCombo > MaxCombo then
		NextCombo = 1
	end

	EntityComboCounts[Entity] = NextCombo
	EntityComboTimers[Entity] = workspace:GetServerTimeNow()
end

function ActionExecutor.ResetCombo(Entity: CombatTypes.Entity)
	EntityComboCounts[Entity] = 1
	EntityComboTimers[Entity] = nil
end

function ActionExecutor.CanFeint(Entity: CombatTypes.Entity): boolean
	local CooldownTime = EntityFeintCooldowns[Entity]
	if not CooldownTime then
		return true
	end

	local CurrentTime = workspace:GetServerTimeNow()
	return (CurrentTime - CooldownTime) > 0
end

function ActionExecutor.SetFeintCooldown(Entity: CombatTypes.Entity, Duration: number)
	EntityFeintCooldowns[Entity] = workspace:GetServerTimeNow() + Duration
end

function ActionExecutor.Feint(Entity: CombatTypes.Entity): boolean
	local Context = ActiveContexts[Entity]
	if not Context then
		return false
	end

	if not Context.Metadata.Feintable then
		return false
	end

	if not ActionExecutor.CanFeint(Entity) then
		return false
	end

	if not Context.CustomData.CanFeint then
		return false
	end

	ActionExecutor.SetFeintCooldown(Entity, Context.Metadata.FeintCooldown)
	ActionExecutor.Interrupt(Entity, "Feint")

	if Entity.Player then
		Packets.ActionInterrupted:FireClient(Entity.Player, Entity.Character, "Feint")
	end

	return true
end

return ActionExecutor