--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local MovementModifiers = require(script.Parent.Parent.Utility.MovementModifiers)
local AttackFlags = require(script.Parent.Parent.Utility.AttackFlags)
local AngleValidator = require(script.Parent.Parent.Utility.AngleValidator)
local StyleResolver = require(script.Parent.Parent.Utility.StyleResolver)
local CombatAnimator = require(script.Parent.Parent.Utility.CombatAnimator)

local StyleConfig = require(Shared.Config.Styles.StyleConfig)
local CombatBalance = require(Shared.Config.Balance.CombatBalance)
local StateTypes = require(Shared.Config.Enums.StateTypes)
local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local Block = {}

Block.ActionName = "Block"
Block.ActionType = "Defensive"

local function ApplyGuardBreakState(Context: ActionContext)
	local Entity = Context.Entity
	Entity.States:SetState(StateTypes.GUARD_BROKEN, true)

	local Duration = CombatBalance.Blocking.GuardBreakDuration or 1.5

	task.delay(Duration, function()
		if Entity.States then
			Entity.States:SetState(StateTypes.GUARD_BROKEN, false)

			Ensemble.Events.Publish(CombatEvents.GuardBreakRecovered, {
				Entity = Entity,
			})
		end
	end)
end

local function HandleGuardBreakAttack(Context: ActionContext, Attacker: Entity, IncomingDamage: number): boolean
	local DamageComponent = Context.Entity:GetComponent("Damage")
	if DamageComponent then
		DamageComponent:DealDamage(IncomingDamage, Attacker.Player or Attacker.Character)
	end

	ApplyGuardBreakState(Context)

	Ensemble.Events.Publish(CombatEvents.GuardBroken, {
		Entity = Context.Entity,
		Attacker = Attacker,
		IncomingDamage = IncomingDamage,
		Reason = "GuardBreakAttack",
		Context = Context,
	})

	Ensemble.Events.Publish("DamageIndicatorTriggered", {
		Attacker = Attacker,
		Target = Context.Entity,
		DamageAmount = IncomingDamage,
		HitPosition = Context.Entity.Character:GetPivot().Position,
		IndicatorType = "Crit",
	})

	ActionExecutor.Interrupt(Context.Entity, "GuardBreak")
	return true
end

local function HandleStaminaDepletedGuardBreak(Context: ActionContext, Attacker: Entity, IncomingDamage: number)
	ApplyGuardBreakState(Context)

	Ensemble.Events.Publish(CombatEvents.GuardBroken, {
		Entity = Context.Entity,
		Attacker = Attacker,
		IncomingDamage = IncomingDamage,
		Reason = "StaminaDepleted",
		Context = Context,
	})

	local AnimationId = Context.Metadata.AnimationId :: string

	CombatAnimator.Stop(Context.Entity, AnimationId, 0.1)
	CombatAnimator.Stop(Context.Entity, "BlockHit", 0.1)

	ActionExecutor.Interrupt(Context.Entity, "GuardBreak")
end

local function PlayBlockHitEffects(Context: ActionContext)
	CombatAnimator.Play(Context.Entity, "BlockHit")
end

local function ApplyBlockHitState(Context: ActionContext)
	local Entity = Context.Entity
	Entity.States:SetState(StateTypes.BLOCK_HIT, true)

	local Duration = CombatBalance.Blocking.BlockHitDuration or 0.3

	task.delay(Duration, function()
		if Entity.States then
			Entity.States:SetState(StateTypes.BLOCK_HIT, false)
		end
	end)
end

local function CalculateBlockReduction(Context: ActionContext, IncomingDamage: number): (number, number)
	local DamageReduction = Context.Metadata.DamageReduction or CombatBalance.Blocking.DamageReduction
	local StaminaScalar = Context.Metadata.StaminaDrainScalar or CombatBalance.Blocking.StaminaDrainScalar or 1.0

	local ReducedDamage = IncomingDamage * (1 - DamageReduction)
	local StaminaDrain = IncomingDamage * StaminaScalar

	return ReducedDamage, StaminaDrain
end

local function ConsumeBlockStamina(Context: ActionContext, Attacker: Entity, StaminaDrain: number, IncomingDamage: number): boolean
	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if not StaminaComponent then
		return true
	end

	local CurrentStamina = StaminaComponent:GetStamina()

	if CurrentStamina <= StaminaDrain then
		StaminaComponent:SetStamina(0)
		HandleStaminaDepletedGuardBreak(Context, Attacker, IncomingDamage)
		return false
	end

	StaminaComponent:ConsumeStamina(StaminaDrain)
	return true
end

local function HandleBlockedHit(Context: ActionContext, Attacker: Entity, IncomingDamage: number, HitPosition: Vector3?)
	PlayBlockHitEffects(Context)
	ApplyBlockHitState(Context)

	local ReducedDamage, StaminaDrain = CalculateBlockReduction(Context, IncomingDamage)

	if not ConsumeBlockStamina(Context, Attacker, StaminaDrain, IncomingDamage) then
		return
	end

	Ensemble.Events.Publish("DamageIndicatorTriggered", {
		Attacker = Attacker,
		Target = Context.Entity,
		DamageAmount = 0,
		HitPosition = HitPosition or Context.Entity.Character:GetPivot().Position,
		IndicatorType = "Blocked",
	})

	Ensemble.Events.Publish(CombatEvents.BlockHit, {
		Entity = Context.Entity,
		Attacker = Attacker,
		IncomingDamage = IncomingDamage,
		ReducedDamage = ReducedDamage,
		StaminaDrain = StaminaDrain,
		HitPosition = HitPosition,
		Context = Context,
	})

	Ensemble.Events.Publish(CombatEvents.DamageBlocked, {
		Entity = Context.Entity,
		Attacker = Attacker,
		BlockedAmount = IncomingDamage,
		Context = Context,
	})
end

local function IsBlockAngleValid(Context: ActionContext, Attacker: Entity): boolean
	local MaxAngle = CombatBalance.Blocking.BlockAngle or 180
	local HalfAngle = MaxAngle / 2

	if not Context.Entity.Character or not Attacker.Character then
		return true
	end

	return AngleValidator.IsWithinAngle(Context.Entity.Character, Attacker.Character, HalfAngle)
end

function Block.BuildMetadata(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
	local StyleName = StyleResolver.GetEntityStyleOrDefault(Entity, InputData)

	local AnimationId = StyleConfig.GetAnimation(StyleName, "Block")
	if not AnimationId then
		AnimationId = StyleConfig.GetAnimation("Fists", "Block")
	end

	return {
		ActionName = "Block",
		ActionType = "Defensive",
		AnimationSet = StyleName,
		DamageReduction = CombatBalance.Blocking.DamageReduction,
		StaminaDrainOnHit = CombatBalance.Blocking.StaminaDrainOnHit,
		StaminaDrainScalar = CombatBalance.Blocking.StaminaDrainScalar,
		AnimationId = AnimationId,
	}
end

function Block.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "Block")
	if not CanPerform then
		return false, Reason
	end

	return true, nil
end

function Block.OnStart(Context: ActionContext)
	Context.Entity.States:SetState("Blocking", true)

	local Multiplier = CombatBalance.Blocking.MovementSpeedMultiplier or 0.5
	MovementModifiers.SetModifier(Context.Entity, "Blocking", Multiplier)

	Ensemble.Events.Publish(CombatEvents.BlockStarted, {
		Entity = Context.Entity,
		Context = Context,
	})
end

function Block.OnExecute(Context: ActionContext)
	local AnimationId = Context.Metadata.AnimationId :: string

	CombatAnimator.Play(Context.Entity, AnimationId)

	while not Context.Interrupted do
		task.wait(0.1)

		if not Context.Entity.States:GetState("Blocking") then
			break
		end
	end
end

function Block.OnHit(Context: ActionContext, Attacker: Entity, IncomingDamage: number, Flags: { string }?, HitPosition: Vector3?): boolean
	local AnimationId = Context.Metadata.AnimationId :: string

	if ActionExecutor.TriggerWindow(Context, Attacker) then
		CombatAnimator.Stop(Context.Entity, AnimationId, 0.1)
		return true
	end

	if not IsBlockAngleValid(Context, Attacker) then
		return false
	end

	if ActionExecutor.TriggerWindow(Context, Attacker) then
		CombatAnimator.Stop(Context.Entity, AnimationId, 0.1)
		return true
	end

	if Flags and AttackFlags.HasFlag(Flags, "GuardBreak") then
		return HandleGuardBreakAttack(Context, Attacker, IncomingDamage)
	end

	HandleBlockedHit(Context, Attacker, IncomingDamage, HitPosition)
	return true
end

function Block.OnInterrupt(Context: ActionContext)
	local AnimationId = Context.Metadata.AnimationId :: string
	CombatAnimator.Stop(Context.Entity, AnimationId, 0.1)
end

function Block.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Blocking", false)
	MovementModifiers.ClearModifier(Context.Entity, "Blocking")

	Ensemble.Events.Publish(CombatEvents.BlockEnded, {
		Entity = Context.Entity,
		Context = Context,
	})
end

return Block