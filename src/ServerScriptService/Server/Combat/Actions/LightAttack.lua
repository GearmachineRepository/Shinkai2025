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
local EntityAnimator = require(script.Parent.Parent.Utility.EntityAnimator)

local Packets = require(Shared.Networking.Packets)
local StyleConfig = require(Shared.Config.Styles.StyleConfig)
local ItemDatabase = require(Shared.Config.Data.ItemDatabase)
local CombatBalance = require(Shared.Config.Balance.CombatBalance)
local ActionValidator = require(Shared.Utility.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local LightAttack = {}

LightAttack.ActionName = "LightAttack"
LightAttack.ActionType = "Attack"

local COOLDOWN_ID = "LightAttack"

local PRESERVE_ANIMATION_INTERRUPTS = {
	PerfectGuard = true,
	Counter = true,
}

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

function LightAttack.BuildMetadata(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
	local ItemId = GetEquippedItemId(Entity, InputData)
	if not ItemId then
		return nil
	end

	local ItemData = ItemDatabase.GetItem(ItemId)
	if not ItemData then
		return nil
	end

	local StyleName = ItemData.Style
	if not StyleName then
		return nil
	end

	local ComboIndex = ActionExecutor.GetComboCount(Entity, "LightAttack")
	local AttackData = StyleConfig.GetAttack(StyleName, "M1", ComboIndex)
	local Timing = StyleConfig.GetTiming(StyleName)

	if not AttackData then
		return nil
	end

	local Modifiers = ItemData.Modifiers

	local Metadata: ActionMetadata = {
		ActionName = "LightAttack",
		ActionType = "Attack",
		AnimationSet = StyleName,
		AnimationId = AttackData.AnimationId,
		ComboIndex = ComboIndex,

		Damage = ApplyStatModifiers(AttackData.Damage, Modifiers and Modifiers.DamageMultiplier),
		StaminaCost = ApplyStatModifiers(AttackData.StaminaCost, Modifiers and Modifiers.StaminaCostMultiplier),
		HitStun = AttackData.HitStun,

		HitboxSize = AttackData.Hitbox and AttackData.Hitbox.Size,
		HitboxOffset = AttackData.Hitbox and AttackData.Hitbox.Offset,

		Knockback = AttackData.Knockback,

		Feintable = Timing.Feintable,
		FeintEndlag = Timing.FeintEndlag,
		FeintCooldown = Timing.FeintCooldown,
		ComboEndlag = Timing.ComboEndlag,
		ComboResetTime = Timing.ComboResetTime,
		StaminaCostHitReduction = Timing.StaminaCostHitReduction,

		FallbackHitStart = Timing.FallbackHitStart,
		FallbackHitEnd = Timing.FallbackHitEnd,
		FallbackLength = Timing.FallbackLength,

		Flag = AttackData.Flag,
		Flags = AttackData.Flags,
	}

	return Metadata
end

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
	local ShouldStopAnimation = not PRESERVE_ANIMATION_INTERRUPTS[Context.InterruptReason]
	if not AnimationId then return end

	if ShouldStopAnimation then
		local Player = Context.Entity.Player
		local Character = Context.Entity.Character
		if Player then
			Packets.StopAnimation:FireClient(Player, AnimationId, 0.15)
		elseif Character then
			EntityAnimator.Stop(Character, AnimationId, 0.15)
		end
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