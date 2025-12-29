--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local ActionValidator = require(Shared.Utils.ActionValidator)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local MovementModifiers = require(Server.Combat.MovementModifiers)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local AttackFlags = require(Server.Combat.AttackFlags)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)
local PerfectGuard = require(script.Parent.PerfectGuard)
local Counter = require(script.Parent.Counter)

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
		AnimationSet = AnimationSets["Fists"]
	end

	local BlockData = AnimationSet and AnimationSet.Block
	local AnimationId = BlockData and BlockData.AnimationId

	local Metadata: ActionMetadata = {
		ActionName = "Block",
		ActionType = "Defensive",
		DamageReduction = CombatBalance.Blocking.DAMAGE_REDUCTION,
		StaminaDrainOnHit = CombatBalance.Blocking.STAMINA_DRAIN_ON_HIT,
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
	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	end

	while not Context.Interrupted do
		task.wait(0.1)

		if not Context.Entity.States:GetState("Blocking") then
			break
		end
	end
end

function Block.OnHit(Context: ActionContext, Attacker: Entity, IncomingDamage: number, Flags: { string }?, HitPosition: Vector3?)
	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId
	local ActiveWindow = Context.CustomData.ActiveWindow
	local IsGuardBreak = AttackFlags.HasFlag(Flags, AttackFlags.GUARD_BREAK)

	if ActiveWindow == "PerfectGuard" then
		Context.CustomData.ActiveWindow = nil
		Context.CustomData.WindowTriggered = true
		Context.Entity.States:SetState("PerfectGuardWindow", false)

		PerfectGuard.Trigger(Context, Attacker)

		if Player and AnimationId then
			Packets.StopAnimation:FireClient(Player, AnimationId, 0.1)
		end

		ActionExecutor.Interrupt(Context.Entity, "PerfectGuard")
		return
	end

	if ActiveWindow == "Counter" then
		Context.CustomData.ActiveWindow = nil
		Context.CustomData.WindowTriggered = true
		Context.Entity.States:SetState("CounterWindow", false)

		Counter.Trigger(Context, Attacker)

		if Player and AnimationId then
			Packets.StopAnimation:FireClient(Player, AnimationId, 0.1)
		end

		ActionExecutor.Interrupt(Context.Entity, "Counter")
		return
	end

	if IsGuardBreak then
		local DamageComponent = Context.Entity:GetComponent("Damage")
		if DamageComponent then
			-- local AttackerRoot = Attacker.Character and Attacker.Character:FindFirstChild("HumanoidRootPart")
			-- local KnockbackDirection = if AttackerRoot then AttackerRoot.CFrame.LookVector else Vector3.zero
			DamageComponent:DealDamage(IncomingDamage, Attacker.Player or Attacker.Character) --, KnockbackDirection
		end

		Context.Entity.States:SetState(StateTypes.GUARD_BROKEN, true)

		Ensemble.Events.Publish(CombatEvents.GuardBroken, {
			Entity = Context.Entity,
			Attacker = Attacker,
			IncomingDamage = IncomingDamage,
			Reason = "GuardBreakAttack",
			Context = Context,
		})

		task.delay(CombatBalance.Blocking.GUARD_BREAK_DURATION or 1.5, function()
			if Context.Entity.States then
				Context.Entity.States:SetState(StateTypes.GUARD_BROKEN, false)
			end
		end)

		ActionExecutor.Interrupt(Context.Entity, "GuardBreak")
		return
	end

	if Player then
		Packets.PlayAnimation:FireClient(Player, "BlockHit")
	end

	Context.Entity.States:SetState(StateTypes.BLOCK_HIT, true)

	Packets.PlayVfxReplicate:Fire(
		Attacker.Player or Attacker.Character,
		"BlockHit",
		{
			Target = Context.Entity.Character,
			HitPosition = HitPosition,
		}
	)

	task.delay(CombatBalance.Blocking.BLOCK_HIT_DURATION or 0.3, function()
		if Context.Entity.States then
			Context.Entity.States:SetState(StateTypes.BLOCK_HIT, false)
		end
	end)

	local DamageReduction = Context.Metadata.DamageReduction or CombatBalance.Blocking.DAMAGE_REDUCTION
	local StaminaScalar = Context.Metadata.StaminaDrainScalar or CombatBalance.Blocking.STAMINA_DRAIN_SCALAR or 1.0

	local ReducedDamage = IncomingDamage * (1 - DamageReduction)
	local StaminaDrain = IncomingDamage * StaminaScalar

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent then
		local CurrentStamina = StaminaComponent:GetStamina()

		if CurrentStamina <= StaminaDrain then
			StaminaComponent:SetStamina(0)

			Context.Entity.States:SetState(StateTypes.GUARD_BROKEN, true)

			Ensemble.Events.Publish(CombatEvents.GuardBroken, {
				Entity = Context.Entity,
				Attacker = Attacker,
				IncomingDamage = IncomingDamage,
				Reason = "StaminaDepleted",
				Context = Context,
			})

			task.delay(CombatBalance.Blocking.GUARD_BREAK_DURATION or 1.5, function()
				if Context.Entity.States then
					Context.Entity.States:SetState(StateTypes.GUARD_BROKEN, false)
				end
			end)

			ActionExecutor.Interrupt(Context.Entity, "GuardBreak")

			if Player and AnimationId then
				Packets.StopAnimation:FireClient(Player, AnimationId, 0.1)
				Packets.StopAnimation:FireClient(Player, "BlockHit", 0.1)
			end

			return
		end

		StaminaComponent:ConsumeStamina(StaminaDrain)
	end

	Ensemble.Events.Publish(CombatEvents.BlockHit, {
		Entity = Context.Entity,
		Attacker = Attacker,
		IncomingDamage = IncomingDamage,
		ReducedDamage = ReducedDamage,
		StaminaDrain = StaminaDrain,
		Context = Context,
	})

	Ensemble.Events.Publish(CombatEvents.DamageBlocked, {
		Entity = Context.Entity,
		Attacker = Attacker,
		BlockedAmount = IncomingDamage,
		Context = Context,
	})
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

	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.StopAnimation:FireClient(Player, AnimationId, 0.15)
	end
end

return Block