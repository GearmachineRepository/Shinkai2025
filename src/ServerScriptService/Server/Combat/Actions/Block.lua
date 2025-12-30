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

local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local ActionValidator = require(Shared.Utils.ActionValidator)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local Block = {}

Block.ActionName = "Block"
Block.ActionType = "Defensive"

Block.DefaultMetadata = {
	ActionName = "Block",
	ActionType = "Defensive",
	DamageReduction = CombatBalance.Blocking.DAMAGE_REDUCTION,
	StaminaDrainOnHit = CombatBalance.Blocking.STAMINA_DRAIN_ON_HIT,
}

local function PlayAnimation(Context: ActionContext, AnimationId: string?)
	if not AnimationId then
		return
	end

	local Player = Context.Entity.Player
	if Player then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	end
end

local function StopAnimation(Context: ActionContext, AnimationId: string?, FadeTime: number?)
	if not AnimationId then
		return
	end

	local Player = Context.Entity.Player
	if Player then
		Packets.StopAnimation:FireClient(Player, AnimationId, FadeTime or 0.15)
	end
end

local function ApplyGuardBreakState(Context: ActionContext)
	local Entity = Context.Entity
	Entity.States:SetState(StateTypes.GUARD_BROKEN, true)

	local Duration = CombatBalance.Blocking.GUARD_BREAK_DURATION or 1.5

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

	StopAnimation(Context, Context.Metadata.AnimationId, 0.1)
	StopAnimation(Context, "BlockHit", 0.1)

	ActionExecutor.Interrupt(Context.Entity, "GuardBreak")
end

local function PlayBlockHitEffects(Context: ActionContext)
	local Player = Context.Entity.Player

	if Player then
		Packets.PlayAnimation:FireClient(Player, "BlockHit")
	end
end

local function ApplyBlockHitState(Context: ActionContext)
	local Entity = Context.Entity
	Entity.States:SetState(StateTypes.BLOCK_HIT, true)

	local Duration = CombatBalance.Blocking.BLOCK_HIT_DURATION or 0.3

	task.delay(Duration, function()
		if Entity.States then
			Entity.States:SetState(StateTypes.BLOCK_HIT, false)
		end
	end)
end

local function CalculateBlockReduction(Context: ActionContext, IncomingDamage: number): (number, number)
	local DamageReduction = Context.Metadata.DamageReduction or CombatBalance.Blocking.DAMAGE_REDUCTION
	local StaminaScalar = Context.Metadata.StaminaDrainScalar or CombatBalance.Blocking.STAMINA_DRAIN_SCALAR or 1.0

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

function Block.BuildMetadata(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
	local ItemId = InputData and InputData.ItemId
	local AnimationSetName = "Fists"

	if not ItemId then
		local ToolComponent = Entity:GetComponent("Tool")
		if ToolComponent then
			local EquippedTool = ToolComponent:GetEquippedTool()
			if EquippedTool and EquippedTool.ToolId then
				ItemId = EquippedTool.ToolId
			end
		end
	end

	if ItemId then
		local ItemData = ItemDatabase.GetItem(ItemId)
		if ItemData and ItemData.AnimationSet then
			AnimationSetName = ItemData.AnimationSet
		end
	end

	local AnimationSet = AnimationSets.Get(AnimationSetName)
	if not AnimationSet then
		AnimationSet = AnimationSets.Get("Fists")
	end

	local BlockData = AnimationSet and AnimationSet.Block
	local AnimationId = BlockData and BlockData.AnimationId

	local Metadata: ActionMetadata = {
		ActionName = "Block",
		ActionType = "Defensive",
		AnimationSet = AnimationSetName,
		DamageReduction = CombatBalance.Blocking.DAMAGE_REDUCTION,
		StaminaDrainOnHit = CombatBalance.Blocking.STAMINA_DRAIN_ON_HIT,
		StaminaDrainScalar = CombatBalance.Blocking.STAMINA_DRAIN_SCALAR,
		AnimationId = AnimationId,
	}

	return Metadata
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

	local Multiplier = CombatBalance.Blocking.MOVEMENT_SPEED_MULTIPLIER or 0.5
	MovementModifiers.SetModifier(Context.Entity, "Blocking", Multiplier)

	Ensemble.Events.Publish(CombatEvents.BlockStarted, {
		Entity = Context.Entity,
		Context = Context,
	})
end

function Block.OnExecute(Context: ActionContext)
	PlayAnimation(Context, Context.Metadata.AnimationId)

	while not Context.Interrupted do
		task.wait(0.1)

		if not Context.Entity.States:GetState("Blocking") then
			break
		end
	end
end

local function IsBlockAngleValid(Context: ActionContext, Attacker: Entity): boolean
	local MaxAngle = CombatBalance.Blocking.BLOCK_ANGLE or 180
	local HalfAngle = MaxAngle / 2

	if not Context.Entity.Character or not Attacker.Character then
		return true
	end

	return AngleValidator.IsWithinAngle(Context.Entity.Character, Attacker.Character, HalfAngle)
end

function Block.OnHit(Context: ActionContext, Attacker: Entity, IncomingDamage: number, Flags: { string }?, HitPosition: Vector3?): boolean
	if not IsBlockAngleValid(Context, Attacker) then
		Ensemble.Events.Publish(CombatEvents.BlockMissed, {
			Entity = Context.Entity,
			Attacker = Attacker,
			IncomingDamage = IncomingDamage,
			Reason = "AttackFromBehind",
			Context = Context,
		})
		return false
	end

	if ActionExecutor.TriggerWindow(Context, Attacker) then
		StopAnimation(Context, Context.Metadata.AnimationId, 0.1)
		return true
	end

	local IsGuardBreak = AttackFlags.HasFlag(Flags, AttackFlags.GUARD_BREAK)

	if IsGuardBreak then
		HandleGuardBreakAttack(Context, Attacker, IncomingDamage)
		return true
	end

	HandleBlockedHit(Context, Attacker, IncomingDamage, HitPosition)
	return true
end

function Block.OnInterrupt(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.BlockEnded, {
		Entity = Context.Entity,
		Reason = Context.InterruptReason,
		Context = Context,
	})
end

function Block.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Blocking", false)
	MovementModifiers.ClearModifier(Context.Entity, "Blocking")
	StopAnimation(Context, Context.Metadata.AnimationId)
end

return Block