--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local AttackBase = require(Server.Combat.AttackBase)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local ActionValidator = require(Shared.Utils.ActionValidator)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local HeavyAttack = {}

HeavyAttack.ActionName = "HeavyAttack"
HeavyAttack.ActionType = "Attack"

local COOLDOWN_ID = "HeavyAttack"

function HeavyAttack.BuildMetadata(_Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
	local ItemId = InputData and InputData.ItemId
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
		ActionName = "HeavyAttack",
		ActionType = "Attack",
		AnimationSet = AnimationSetName,
		AnimationId = AttackData.AnimationId,

		Damage = FinalDamage,
		StaminaCost = FinalStaminaCost,
		HitStun = AttackData.HitStun,
		--PostureDamage = AttackData.PostureDamage,

		HitboxSize = AttackData.Hitbox.Size,
		HitboxOffset = AttackData.Hitbox.Offset,

		Feintable = SetMetadata.Feintable,
		FeintEndlag = SetMetadata.FeintEndlag,
		FeintCooldown = SetMetadata.FeintCooldown,
		ActionCooldown = SetMetadata.HeavyAttackCooldown,
		StaminaCostHitReduction = SetMetadata.StaminaCostHitReduction,

		FallbackHitStart = SetMetadata.FallbackTimings.HitStart,
		FallbackHitEnd = SetMetadata.FallbackTimings.HitEnd,
		FallbackLength = SetMetadata.FallbackTimings.Length,
	}

	return Metadata
end

function HeavyAttack.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "M2")
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

	AttackBase.SetupHitbox(Context, function(Target: Entity)
		HeavyAttack.OnHit(Context, Target, 1)
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

function HeavyAttack.OnHit(Context: ActionContext, Target: Entity, _HitIndex: number)
	if not Context.CustomData.HitWindowOpen then
		return
	end

	local WasBlocked = AttackBase.ProcessHit(Context, Target)

	if not WasBlocked then
		Ensemble.Events.Publish(CombatEvents.AttackHit, {
			Entity = Context.Entity,
			Target = Target,
			ActionName = "HeavyAttack",
			Damage = Context.Metadata.Damage,
			Context = Context,
		})
	end
end

function HeavyAttack.OnInterrupt(Context: ActionContext)
	if Context.InterruptReason == "Feint" then
		Ensemble.Events.Publish(CombatEvents.FeintExecuted, {
			Entity = Context.Entity,
			ActionName = "HeavyAttack",
			Context = Context,
		})

		local FeintEndlag = Context.Metadata.FeintEndlag or 0
		if FeintEndlag > 0 then
			task.wait(FeintEndlag)
		end
	end
end

function HeavyAttack.OnCleanup(Context: ActionContext)
	AttackBase.CleanupAttack(Context)
end

return HeavyAttack