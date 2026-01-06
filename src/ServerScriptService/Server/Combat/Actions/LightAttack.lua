--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local AttackBase = require(script.Parent.Parent.Core.AttackBase)
local MetadataBuilders = require(script.Parent.Parent.Core.MetadataBuilders)
local MovementModifiers = require(script.Parent.Parent.Utility.MovementModifiers)
local CombatAnimator = require(script.Parent.Parent.Utility.CombatAnimator)

local CombatBalance = require(Shared.Config.Balance.CombatBalance)
local StyleConfig = require(Shared.Config.Styles.StyleConfig)
local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local LightAttack = {}

LightAttack.ActionName = "LightAttack"
LightAttack.ActionType = "Attack"
LightAttack.BuildMetadata = MetadataBuilders.ComboAttack("M1", "LightAttack")

local COOLDOWN_ID = "LightAttack"

local PRESERVE_ANIMATION_INTERRUPTS = {
	PerfectGuard = true,
	Counter = true,
}

function LightAttack.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "LightAttack")
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

	local CooldownSeconds = Context.Metadata.ComboEndlag or 0
	if CooldownSeconds > 0 and ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, CooldownSeconds) then
		return false, "OnCooldown"
	end

	return true, nil
end

function LightAttack.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.LastHitTarget = nil
	Context.CustomData.CanFeint = Context.Metadata.Feintable

	Context.Entity.States:SetState("Attacking", true)

	local Multiplier = Context.Metadata.MovementSpeedMultiplier
		or CombatBalance.Attacking.MovementSpeedMultiplier
		or 0.65
	MovementModifiers.SetModifier(Context.Entity, "Attacking", Multiplier)

	AttackBase.SetupHitbox(Context, function(Target: Entity, HitPosition: Vector3?)
		LightAttack.OnHit(Context, Target, HitPosition, 1)
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

function LightAttack.OnHit(Context: ActionContext, Target: Entity, HitPosition: Vector3?, _HitIndex: number?)
	if not Context.CustomData.HitWindowOpen then
		return
	end

	AttackBase.ProcessHit(Context, Target, HitPosition)
end

function LightAttack.OnComplete(Context: ActionContext)
	local Metadata = Context.Metadata
	local StyleName = Metadata.AnimationSet
	if not StyleName then
		return
	end

	local ComboLength = StyleConfig.GetComboLength(StyleName, "M1")
	local ComboIndex = Metadata.ComboIndex or 1

	ActionExecutor.AdvanceCombo(Context.Entity, "LightAttack", ComboIndex, ComboLength)

	if ComboIndex == ComboLength then
		local CooldownSeconds = Metadata.ComboEndlag or 0
		if CooldownSeconds > 0 then
			ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, CooldownSeconds)
		end

		Ensemble.Events.Publish(CombatEvents.ComboFinished, {
			Entity = Context.Entity,
			ActionName = "LightAttack",
			Context = Context,
		})
	end
end

function LightAttack.OnInterrupt(Context: ActionContext)
	local AnimationId = Context.Metadata.AnimationId
	if not AnimationId then
		return
	end

	local ShouldStopAnimation = not PRESERVE_ANIMATION_INTERRUPTS[Context.InterruptReason]
	if ShouldStopAnimation then
		CombatAnimator.Stop(Context.Entity, AnimationId, 0.15)
	end

	if Context.InterruptReason == "Feint" then
		local FeintEndlag = Context.Metadata.FeintEndlag or 0
		if FeintEndlag > 0 then
			task.wait(FeintEndlag)
		end
	end
end

function LightAttack.OnCleanup(Context: ActionContext)
	MovementModifiers.ClearModifier(Context.Entity, "Attacking")
	AttackBase.CleanupAttack(Context)
end

return LightAttack