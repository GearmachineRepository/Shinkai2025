--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)

local DodgeBalance = require(Shared.Configurations.Balance.DashBalance)
local ActionValidator = require(Shared.Utils.ActionValidator)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local Dodge = {}

Dodge.ActionName = "Dodge"
Dodge.ActionType = "Movement"

local COOLDOWN_ID = "Dodge"
local DEFAULT_COOLDOWN = DodgeBalance.CooldownSeconds
local DEFAULT_STAMINA_COST = DodgeBalance.StaminaCost
local DEFAULT_IFRAMES_DURATION = DodgeBalance.IFrameWindow
local DEFAULT_DURATION = DodgeBalance.Duration

Dodge.DefaultMetadata = {
	ActionName = "Dodge",
	ActionType = "Movement",
	ActionCooldown = DEFAULT_COOLDOWN,
	StaminaCost = DEFAULT_STAMINA_COST,
	IFramesDuration = DEFAULT_IFRAMES_DURATION,
	Duration = DEFAULT_DURATION,
	AnimationId = "DodgeRoll",
}

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

	local ActionCooldown = Context.Metadata.ActionCooldown or DEFAULT_COOLDOWN
	if ActionExecutor.IsOnCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown) then
		return false, "OnCooldown"
	end

	return true, nil
end

function Dodge.OnStart(Context: ActionContext)
	Context.Entity.States:SetState("Dodging", true)

	local ActionCooldown = Context.Metadata.ActionCooldown or DEFAULT_COOLDOWN
	if ActionCooldown > 0 then
		ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown)
	end

	local StaminaCost = Context.Metadata.StaminaCost or DEFAULT_STAMINA_COST
	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent and StaminaCost > 0 then
		StaminaComponent:ConsumeStamina(StaminaCost)
	end

	Ensemble.Events.Publish(CombatEvents.DodgeStarted, {
		Entity = Context.Entity,
		Context = Context,
	})
end

function Dodge.OnExecute(Context: ActionContext)
	local IFramesDuration = Context.Metadata.IFramesDuration or DEFAULT_IFRAMES_DURATION
	local TotalDuration = Context.Metadata.Duration or DEFAULT_DURATION

	Context.Entity.States:SetState("Invulnerable", true)

	Ensemble.Events.Publish(CombatEvents.DodgeIFramesStarted, {
		Entity = Context.Entity,
		Duration = IFramesDuration,
	})

	ActionExecutor.ScheduleThread(Context, IFramesDuration, function()
		Context.Entity.States:SetState("Invulnerable", false)

		Ensemble.Events.Publish(CombatEvents.DodgeIFramesEnded, {
			Entity = Context.Entity,
		})
	end, true)

	task.wait(TotalDuration)
end

function Dodge.OnComplete(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.DodgeCompleted, {
		Entity = Context.Entity,
		Context = Context,
	})
end

function Dodge.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Dodging", false)
	Context.Entity.States:SetState("Invulnerable", false)
end

return Dodge