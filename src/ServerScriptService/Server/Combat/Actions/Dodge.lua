--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)
local AnimationTimingCache = require(script.Parent.Parent.Utility.AnimationTimingCache)
local MovementModifiers = require(script.Parent.Parent.Utility.MovementModifiers)
--local LatencyCompensation = require(script.Parent.Parent.Utility.LatencyCompensation)
local EntityAnimator = require(script.Parent.Parent.Utility.EntityAnimator)

local StateTypes = require(Shared.Config.Enums.StateTypes)
local PhysicsBalance = require(Shared.Config.Balance.PhysicsBalance)
local ActionValidator = require(Shared.Utility.ActionValidator)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

type DashComboState = {
	LastDirection: string?,
	DashCount: number,
	LastDashTime: number,
}

local Dodge = {}

Dodge.ActionName = "Dodge"
Dodge.ActionType = "Movement"

local COOLDOWN_ID = "Dodge"
local CONSECUTIVE_COOLDOWN_ID = "DodgeConsecutive"

local DEFAULT_STAMINA_COST = PhysicsBalance.Dash.StaminaCost
local DEFAULT_IFRAMES_DURATION = PhysicsBalance.Dash.IFrameWindow
local DEFAULT_DURATION = PhysicsBalance.Dash.Duration
local DODGE_RECOVERY_PERCENT = PhysicsBalance.Dash.RecoveryPercent
local DEFAULT_ANIMATION = "DashBack"

local CONSECUTIVE_DASHES = PhysicsBalance.Dash.ConsecutiveDashes
local CONSECUTIVE_COOLDOWN = PhysicsBalance.Dash.ConsecutiveCooldown
local EXHAUSTED_COOLDOWN = PhysicsBalance.Dash.ExhaustedCooldown
local COMBO_RESET_TIME = PhysicsBalance.Dash.ComboResetTime
local EXHAUSTED_DURATION = PhysicsBalance.Dash.ExhaustedDuration

local EntityDashStates: { [Entity]: DashComboState } = {}

Dodge.DefaultMetadata = {
	ActionName = "Dodge",
	ActionType = "Movement",
	StaminaCost = DEFAULT_STAMINA_COST,
	IFramesDuration = DEFAULT_IFRAMES_DURATION,
	Duration = DEFAULT_DURATION,
	AnimationId = DEFAULT_ANIMATION,
}

local DIRECTION_TO_ANIMATION: { [string]: string } = {
	Forward = "DashForward",
	Back = "DashBack",
	Left = "DashLeft",
	Right = "DashRight",
}

local function GetDashState(Entity: Entity): DashComboState
	local State = EntityDashStates[Entity]
	if not State then
		State = {
			LastDirection = nil,
			DashCount = 0,
			LastDashTime = 0,
		}
		EntityDashStates[Entity] = State
	end
	return State
end

local function ResetDashCombo(Entity: Entity)
	local State = EntityDashStates[Entity]
	if State then
		State.LastDirection = nil
		State.DashCount = 0
	end
end

local function CheckComboExpiry(Entity: Entity)
	local State = EntityDashStates[Entity]
	if not State or State.DashCount == 0 then
		return
	end

	local TimeSinceLastDash = workspace:GetServerTimeNow() - State.LastDashTime
	if TimeSinceLastDash >= COMBO_RESET_TIME then
		ResetDashCombo(Entity)
	end
end

local function GetDodgeDuration(AnimationKey: string?): number
	local AnimationName = AnimationKey or DEFAULT_ANIMATION
	local AnimationLength = AnimationTimingCache.GetLength(AnimationName)
	if AnimationLength then
		return AnimationLength
	end
	return DEFAULT_DURATION
end

local function StopDodgeAnimation(Context: ActionContext, FadeTime: number?)
	local AnimationId = Context.Metadata.AnimationId
	if not AnimationId then
		return
	end

	local Player = Context.Entity.Player
	local Character = Context.Entity.Character
	local ActualFadeTime = FadeTime or 0.1

	if Player then
		Packets.StopAnimation:FireClient(Player, AnimationId, ActualFadeTime)
	elseif Character then
		EntityAnimator.Stop(Character, AnimationId, ActualFadeTime)
	end
end

local function ApplyDashExhaustion(Context, Entity: Entity)
	Entity.States:SetState(StateTypes.DASH_EXHAUSTED, true)

	local Multiplier = PhysicsBalance.Dash.MovementSpeedMultiplier

	MovementModifiers.SetModifier(Context.Entity, StateTypes.DASH_EXHAUSTED, Multiplier)

	task.delay(EXHAUSTED_DURATION, function()
		if Entity and Entity.States then
			Entity.States:SetState(StateTypes.DASH_EXHAUSTED, false)
		end
	end)
end

function Dodge.BuildMetadata(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
	CheckComboExpiry(Entity)

	local Direction = InputData and InputData.Direction or "Back"
	local AnimationId = DIRECTION_TO_ANIMATION[Direction] or DEFAULT_ANIMATION

	local State = GetDashState(Entity)

	if State.LastDirection == Direction then
		return nil
	end

	if State.DashCount >= CONSECUTIVE_DASHES then
		return nil
	end

	local Metadata: ActionMetadata = {
		ActionName = "Dodge",
		ActionType = "Movement",
		StaminaCost = DEFAULT_STAMINA_COST,
		IFramesDuration = DEFAULT_IFRAMES_DURATION,
		Duration = DEFAULT_DURATION,
		AnimationId = AnimationId,
		Direction = Direction,
	}

	return Metadata
end

function Dodge.CanExecute(Context: ActionContext): (boolean, string?)
	local CanPerform, Reason = ActionValidator.CanPerform(Context.Entity.States, "Dodge")
	if not CanPerform then
		return false, Reason
	end

	local StatComponent = Context.Entity:GetComponent("Stats")
	if StatComponent then
		local StaminaCost = Context.Metadata.StaminaCost or DEFAULT_STAMINA_COST
		if StatComponent:GetStat("Stamina") < StaminaCost then
			return false, "NoStamina"
		end
	end

	CheckComboExpiry(Context.Entity)

	local State = GetDashState(Context.Entity)
	local Direction = Context.Metadata.Direction

	if Direction and State.LastDirection == Direction then
		return false, "SameDirection"
	end

	if State.DashCount >= CONSECUTIVE_DASHES then
		return false, "MaxDashes"
	end

	if State.DashCount > 0 then
		if ActionExecutor.IsOnCooldown(Context.Entity, CONSECUTIVE_COOLDOWN_ID, CONSECUTIVE_COOLDOWN) then
			return false, "OnCooldown"
		end
	end

	return true, nil
end

function Dodge.OnStart(Context: ActionContext)
	Context.Entity.States:SetState(StateTypes.DODGING, true)

	local State = GetDashState(Context.Entity)
	local Direction = Context.Metadata.Direction

	State.DashCount = State.DashCount + 1
	State.LastDashTime = workspace:GetServerTimeNow()
	State.LastDirection = Direction

	ActionExecutor.StartCooldown(Context.Entity, CONSECUTIVE_COOLDOWN_ID, CONSECUTIVE_COOLDOWN)

	local StaminaCost = Context.Metadata.StaminaCost or DEFAULT_STAMINA_COST
	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent and StaminaCost > 0 then
		StaminaComponent:ConsumeStamina(StaminaCost)
	end

	Ensemble.Events.Publish(CombatEvents.DodgeStarted, {
		Entity = Context.Entity,
		Context = Context,
		DashCount = State.DashCount,
	})
end

function Dodge.OnExecute(Context: ActionContext)
	local IFramesDuration = Context.Metadata.IFramesDuration or DEFAULT_IFRAMES_DURATION
	local AnimationId = Context.Metadata.AnimationId
	local TotalDuration = GetDodgeDuration(AnimationId)
	local RecoveryTime = TotalDuration * DODGE_RECOVERY_PERCENT

	Ensemble.Events.Publish(CombatEvents.DodgeIFramesStarted, {
		Entity = Context.Entity,
		Duration = IFramesDuration,
	})

	local States = Context.Entity:GetComponent("States")
	if not States then
		return
	end

	local Blocking = States:GetState(StateTypes.BLOCKING)
	if not Blocking then
		--local InputTimestamp = Context.InputData and Context.InputData.InputTimestamp
		--local Compensation = LatencyCompensation.GetCompensation(InputTimestamp)
		--local AdjustedIFrames = IFramesDuration + Compensation

		Context.Entity.States:SetState(StateTypes.INVULNERABLE, true)

		ActionExecutor.ScheduleThread(Context, IFramesDuration, function() -- AdjustedIFrames
			Context.Entity.States:SetState(StateTypes.INVULNERABLE, false)

			Ensemble.Events.Publish(CombatEvents.DodgeIFramesEnded, {
				Entity = Context.Entity,
			})
		end, true)
	end

	task.wait(RecoveryTime)
end

function Dodge.OnComplete(Context: ActionContext)
	local State = GetDashState(Context.Entity)
	local IsLastDash = State.DashCount >= CONSECUTIVE_DASHES

	if IsLastDash then
		ApplyDashExhaustion(Context, Context.Entity)
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, EXHAUSTED_COOLDOWN)
		ResetDashCombo(Context.Entity)
	end

	Ensemble.Events.Publish(CombatEvents.DodgeCompleted, {
		Entity = Context.Entity,
		Context = Context,
	})
end

function Dodge.OnInterrupt(Context: ActionContext)
	StopDodgeAnimation(Context, 0.1)
end

function Dodge.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState(StateTypes.DODGING, false)
	Context.Entity.States:SetState(StateTypes.INVULNERABLE, false)
	MovementModifiers.ClearModifier(Context.Entity, StateTypes.DASH_EXHAUSTED)
	StopDodgeAnimation(Context, 0.15)
end

function Dodge.CleanupEntity(Entity: Entity)
	EntityDashStates[Entity] = nil
end

return Dodge