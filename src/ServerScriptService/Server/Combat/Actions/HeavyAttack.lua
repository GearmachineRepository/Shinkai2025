--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local AttackBase = require(script.Parent.Parent.Core.AttackBase)
local MovementModifiers = require(script.Parent.Parent.Utility.MovementModifiers)

local EntityAnimator = require(Server.Ensemble.Utilities.EntityAnimator)
local Packets = require(Shared.Networking.Packets)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local ActionValidator = require(Shared.Utils.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local HeavyAttack = {}

HeavyAttack.ActionName = "HeavyAttack"
HeavyAttack.ActionType = "Attack"

local COOLDOWN_ID = "HeavyAttack"

local function GetEquippedItemId(Entity: Entity, InputData: { [string]: any }?): string?
	if InputData and InputData.ItemId then
		return InputData.ItemId
	end

	local ToolComponent = Entity:GetComponent("Tool")
	if ToolComponent then
		local EquippedTool = ToolComponent:GetEquippedTool()
		if EquippedTool and EquippedTool.ToolId then
			return EquippedTool.ToolId
		end
	end

	return nil
end

local function ApplyStatModifiers(BaseValue: number, Multiplier: number?): number
	if Multiplier then
		return BaseValue * Multiplier
	end
	return BaseValue
end

function HeavyAttack.BuildMetadata(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
	local ItemId = GetEquippedItemId(Entity, InputData)
	if not ItemId then
		return nil
	end

	local ItemData = ItemDatabase.GetItem(ItemId)
	if not ItemData then
		return nil
	end

	local AnimationSetName = ItemData.AnimationSet
	if not AnimationSetName then
		return nil
	end

	local AttackData = AnimationSets.GetAttack(AnimationSetName, "M2", 1)
	local SetMetadata = AnimationSets.GetMetadata(AnimationSetName)

	if not AttackData then
		return nil
	end

	local StatModifiers = ItemData.StatModifiers

	local Metadata: ActionMetadata = {
		ActionName = "HeavyAttack",
		ActionType = "Attack",
		AnimationSet = AnimationSetName,
		AnimationId = AttackData.AnimationId,

		Damage = ApplyStatModifiers(AttackData.Damage, StatModifiers and StatModifiers.DamageMultiplier),
		StaminaCost = ApplyStatModifiers(AttackData.StaminaCost, StatModifiers and StatModifiers.StaminaCostMultiplier),
		HitStun = AttackData.HitStun,
		--PostureDamage = AttackData.PostureDamage,

		HitboxSize = AttackData.Hitbox and AttackData.Hitbox.Size,
		HitboxOffset = AttackData.Hitbox and AttackData.Hitbox.Offset,

		Feintable = SetMetadata.Feintable,
		FeintEndlag = SetMetadata.FeintEndlag,
		FeintCooldown = SetMetadata.FeintCooldown,
		ActionCooldown = SetMetadata.HeavyAttackCooldown,
		StaminaCostHitReduction = SetMetadata.StaminaCostHitReduction,

		Knockback = AttackData.Knockback,

		FallbackHitStart = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.HitStart,
		FallbackHitEnd = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.HitEnd,
		FallbackLength = SetMetadata.FallbackTimings and SetMetadata.FallbackTimings.Length,

		Flag = AttackData.Flag,
		Flags = AttackData.Flags,
	}

	return Metadata
end

function HeavyAttack.CanExecute(Context: ActionContext): (boolean, string?)
        local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "HeavyAttack", Context.Metadata.ValidationOverrides)
	if not CanPerform then
		return false, Reason
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if not StatComponent then
		return false, "NoStatComponent"
	end

	local StaminaCost = Context.Metadata.StaminaCost or 0
	if StatComponent:GetStat("Stamina") < StaminaCost then
		return false, "NoStamina"
	end

	local ActionCooldown = Context.Metadata.ActionCooldown or 0
	if ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown) then
		return false, "OnCooldown"
	end

	return true, nil
end

function HeavyAttack.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.LastHitTarget = nil
	Context.CustomData.CanFeint = Context.Metadata.Feintable

	Context.Entity.States:SetState("Attacking", true)

	local ActionCooldown = Context.Metadata.ActionCooldown or 0
	if ActionCooldown > 0 then
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown)
	end

	local Multiplier = Context.Metadata.MovementSpeedMultiplier
		or CombatBalance.Attacking.DEFAULT_MOVEMENT_SPEED_MULTIPLIER
		or 0.65
	MovementModifiers.SetModifier(Context.Entity, "Attacking", Multiplier)

	AttackBase.SetupHitbox(Context, function(Target: Entity, HitPosition: Vector3?)
		HeavyAttack.OnHit(Context, Target, HitPosition, 1)
	end)
end

function HeavyAttack.OnExecute(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.AttackStarted, {
		Entity = Context.Entity,
		ActionName = "HeavyAttack",
		Context = Context,
	})

	AttackBase.ExecuteTimedAttack(Context, {
		OnHitStart = function()
			AttackBase.ConsumeStamina(Context)
		end,
		OnHitEnd = function()
			AttackBase.HandleStaminaRefund(Context)
		end,
	})
end

function HeavyAttack.OnHit(Context: ActionContext, Target: Entity, HitPosition: Vector3?, _HitIndex: number?)
	if not Context.CustomData.HitWindowOpen then
		return
	end

	AttackBase.ProcessHit(Context, Target, HitPosition)
end

function HeavyAttack.OnInterrupt(Context: ActionContext)
	if Context.InterruptReason == "Feint" then
		local AnimationId = Context.Metadata.AnimationId
		if not AnimationId then return  end

		local Player = Context.Entity.Player
		local Character = Context.Entity.Character
		if Player then
			Packets.StopAnimation:FireClient(Player, AnimationId, 0.25)
		elseif Character then
			EntityAnimator.Stop(Character, AnimationId, 0.25)
		end

		ActionExecutor.ClearCooldown(Context.Entity, COOLDOWN_ID)

		local FeintEndlag = Context.Metadata.FeintEndlag or 0
		if FeintEndlag > 0 then
			task.wait(FeintEndlag)
		end
	end
end

function HeavyAttack.OnCleanup(Context: ActionContext)
	MovementModifiers.ClearModifier(Context.Entity, "Attacking")
	AttackBase.CleanupAttack(Context)
end

return HeavyAttack