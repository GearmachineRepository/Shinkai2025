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

local LightAttack = {}

LightAttack.ActionName = "LightAttack"
LightAttack.ActionType = "Attack"

function LightAttack.BuildMetadata(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
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

	local ComboIndex = ActionExecutor.GetComboCount(Entity, "LightAttack")
	local AttackData = AnimationSets.GetAttack(AnimationSetName, "M1", ComboIndex)
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
		ActionName = "LightAttack",
		ActionType = "Attack",
		AnimationSet = AnimationSetName,
		AnimationId = AttackData.AnimationId,
		ComboIndex = ComboIndex,

		Damage = FinalDamage,
		StaminaCost = FinalStaminaCost,
		HitStun = AttackData.HitStun,
		--PostureDamage = AttackData.PostureDamage,

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

function LightAttack.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "M1")
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

	return true, nil
end

function LightAttack.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.LastHitTarget = nil
	Context.CustomData.CanFeint = Context.Metadata.Feintable

	Context.Entity.States:SetState("Attacking", true)

	AttackBase.SetupHitbox(Context, function(Target: Entity)
		LightAttack.OnHit(Context, Target, 1)
	end)
end

function LightAttack.OnExecute(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.AttackStarted, {
		Entity = Context.Entity,
		ActionName = "LightAttack",
		ComboIndex = Context.Metadata.ComboIndex,
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

function LightAttack.OnHit(Context: ActionContext, Target: Entity, _HitIndex: number)
	if not Context.CustomData.HitWindowOpen then
		return
	end

	AttackBase.ApplyDamage(Context, Target)
	AttackBase.ApplyHitStun(Context, Target)

	Ensemble.Events.Publish(CombatEvents.AttackHit, {
		Entity = Context.Entity,
		Target = Target,
		ActionName = "LightAttack",
		ComboIndex = Context.Metadata.ComboIndex,
		Damage = Context.Metadata.Damage,
		Context = Context,
	})
end

function LightAttack.OnComplete(Context: ActionContext)
	local Metadata = Context.Metadata
	local AnimationSetName = Metadata.AnimationSet

	if not AnimationSetName then
		return
	end

	local ComboLength = AnimationSets.GetComboLength(AnimationSetName, "M1")
	local ComboIndex = Metadata.ComboIndex or 1

	ActionExecutor.AdvanceCombo(Context.Entity, "LightAttack", ComboIndex, ComboLength)

	if ComboIndex == ComboLength and Metadata.ComboEndlag and Metadata.ComboEndlag > 0 then
		task.wait(Metadata.ComboEndlag)
	end
end

function LightAttack.OnInterrupt(Context: ActionContext)
	if Context.InterruptReason == "Feint" then
		Ensemble.Events.Publish(CombatEvents.FeintExecuted, {
			Entity = Context.Entity,
			ActionName = "LightAttack",
			Context = Context,
		})

		local FeintEndlag = Context.Metadata.FeintEndlag or 0
		if FeintEndlag > 0 then
			task.wait(FeintEndlag)
		end
	end
end

function LightAttack.OnCleanup(Context: ActionContext)
	AttackBase.CleanupAttack(Context)
end

return LightAttack