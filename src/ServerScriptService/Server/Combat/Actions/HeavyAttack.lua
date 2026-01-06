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
local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local HeavyAttack = {}

HeavyAttack.ActionName = "HeavyAttack"
HeavyAttack.ActionType = "Attack"
HeavyAttack.BuildMetadata = MetadataBuilders.SingleAttack("M2", "HeavyAttack")

local COOLDOWN_ID = "HeavyAttack"

local PRESERVE_ANIMATION_INTERRUPTS = {
	PerfectGuard = true,
	Counter = true,
}

function HeavyAttack.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "HeavyAttack")
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

	local CooldownSeconds = Context.Metadata.ActionCooldown or 0
	if CooldownSeconds > 0 and ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, CooldownSeconds) then
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

	local Multiplier = Context.Metadata.MovementSpeedMultiplier
		or CombatBalance.Attacking.MovementSpeedMultiplier
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

function HeavyAttack.OnComplete(Context: ActionContext)
	local CooldownSeconds = Context.Metadata.ActionCooldown or 0
	if CooldownSeconds > 0 then
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, CooldownSeconds)
	end

	Ensemble.Events.Publish(CombatEvents.AttackCompleted, {
		Entity = Context.Entity,
		ActionName = "HeavyAttack",
		Context = Context,
	})
end

function HeavyAttack.OnInterrupt(Context: ActionContext)
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

function HeavyAttack.OnCleanup(Context: ActionContext)
	MovementModifiers.ClearModifier(Context.Entity, "Attacking")
	AttackBase.CleanupAttack(Context)
end

return HeavyAttack