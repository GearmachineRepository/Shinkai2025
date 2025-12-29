--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local ActionValidator = require(Shared.Utils.ActionValidator)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
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

function Block.OnHit(Context: ActionContext, Attacker: Entity, IncomingDamage: number)
	local ActiveWindow = Context.CustomData.ActiveWindow

	if ActiveWindow == "PerfectGuard" then
		Context.CustomData.ActiveWindow = nil
		Context.Entity.States:SetState("PerfectGuardWindow", false)

		PerfectGuard.Trigger(Context, Attacker)
		return
	end

	if ActiveWindow == "Counter" then
		Context.CustomData.ActiveWindow = nil
		Context.Entity.States:SetState("CounterWindow", false)

		Counter.Trigger(Context, Attacker)

		Context.Interrupted = true
		Context.InterruptReason = "Counter"
		return
	end

	local Player = Context.Entity.Player
	if Player then
		Packets.PlayAnimation:FireClient(Player, "BlockHit")
	end

	local DamageReduction = Context.Metadata.DamageReduction or CombatBalance.Blocking.DAMAGE_REDUCTION
	local StaminaScalar = Context.Metadata.StaminaDrainScalar or CombatBalance.Blocking.STAMINA_DRAIN_SCALAR or 1.0

	local ReducedDamage = IncomingDamage * (1 - DamageReduction)
	local StaminaDrain = IncomingDamage * StaminaScalar

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent then
		local CurrentStamina = StaminaComponent:GetStamina()

		if CurrentStamina < StaminaDrain then
			Context.Entity.States:SetState("GuardBroken", true)
			Context.Interrupted = true
			Context.InterruptReason = "GuardBreak"

			Ensemble.Events.Publish(CombatEvents.GuardBroken, {
				Entity = Context.Entity,
				Attacker = Attacker,
				IncomingDamage = IncomingDamage,
				Context = Context,
			})

			task.delay(CombatBalance.Blocking.GUARD_BREAK_DURATION or 1.5, function()
				if Context.Entity.States then
					Context.Entity.States:SetState("GuardBroken", false)
				end
			end)

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

	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.StopAnimation:FireClient(Player, AnimationId, 0.15)
	end
end

return Block