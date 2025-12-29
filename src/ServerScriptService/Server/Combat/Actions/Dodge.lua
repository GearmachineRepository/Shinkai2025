--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(Server.Combat.CombatTypes)
local CombatEvents = require(Server.Combat.CombatEvents)
local ActionExecutor = require(Server.Combat.ActionExecutor)
local ActionValidator = require(Shared.Utils.ActionValidator)
local Packets = require(Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type ActionMetadata = CombatTypes.ActionMetadata

local Dodge = {}

Dodge.ActionName = "Dodge"
Dodge.ActionType = "Movement"

local COOLDOWN_ID = "Dodge"
local DEFAULT_COOLDOWN = 0.8
local DEFAULT_STAMINA_COST = 15
local DEFAULT_IFRAMES_DURATION = 0.3
local DEFAULT_DURATION = 0.5

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
	Context.CustomData.IFramesActive = false
	Context.CustomData.DodgedAttack = false

	local ActionCooldown = Context.Metadata.ActionCooldown or DEFAULT_COOLDOWN
	ActionExecutor.StartCooldown(Context.Entity, COOLDOWN_ID, ActionCooldown)

	Context.Entity.States:SetState("Dodging", true)
	Context.Entity.States:SetState("Invulnerable", true)

	Ensemble.Events.Publish(CombatEvents.DodgeStarted, {
		Entity = Context.Entity,
		Context = Context,
	})
end

function Dodge.OnExecute(Context: ActionContext)
	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.PlayAnimation:FireClient(Player, AnimationId)
	end

	local StaminaComponent = Context.Entity:GetComponent("Stamina")
	if StaminaComponent then
		local StaminaCost = Context.Metadata.StaminaCost or DEFAULT_STAMINA_COST
		StaminaComponent:ConsumeStamina(StaminaCost)

		Ensemble.Events.Publish(CombatEvents.StaminaConsumed, {
			Entity = Context.Entity,
			Amount = StaminaCost,
			ActionName = "Dodge",
			Context = Context,
		})
	end

	Context.CustomData.IFramesActive = true

	local IFramesDuration = Context.Metadata.IFramesDuration or DEFAULT_IFRAMES_DURATION
	task.wait(IFramesDuration)

	Context.CustomData.IFramesActive = false
	Context.Entity.States:SetState("Invulnerable", false)

	local Duration = Context.Metadata.Duration or DEFAULT_DURATION
	local RemainingDuration = Duration - IFramesDuration

	if RemainingDuration > 0 then
		task.wait(RemainingDuration)
	end
end

function Dodge.OnComplete(Context: ActionContext)
	Ensemble.Events.Publish(CombatEvents.DodgeCompleted, {
		Entity = Context.Entity,
		DodgedAttack = Context.CustomData.DodgedAttack,
		Context = Context,
	})

	if Context.CustomData.DodgedAttack then
		Ensemble.Events.Publish(CombatEvents.DodgeSuccessful, {
			Entity = Context.Entity,
			Context = Context,
		})
	end
end

function Dodge.OnCleanup(Context: ActionContext)
	Context.Entity.States:SetState("Dodging", false)
	Context.Entity.States:SetState("Invulnerable", false)

	local Player = Context.Entity.Player
	local AnimationId = Context.Metadata.AnimationId

	if Player and AnimationId then
		Packets.StopAnimation:FireClient(Player, AnimationId, 0.1)
	end
end

return Dodge