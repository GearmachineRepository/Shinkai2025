--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)

local StateHandlers = {}

local CONFLICTING_STATES = {
	[StateTypes.STUNNED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DASHING },
	[StateTypes.RAGDOLLED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DASHING, StateTypes.STUNNED },
	[StateTypes.ATTACKING] = { StateTypes.BLOCKING },
	[StateTypes.DASHING] = { StateTypes.ATTACKING, StateTypes.BLOCKING },
}

local MOVEMENT_BLOCKING_STATES = {
	StateTypes.STUNNED,
	StateTypes.RAGDOLLED,
	StateTypes.ATTACKING,
}

local function GetExpectedWalkSpeed(Entity: any, MovementMode: string?): number
	local RunSpeedStat = Entity.Stats:GetStat("RunSpeed")

	if MovementMode == "run" then
		return Entity.Modifiers:Apply("Speed", RunSpeedStat)
	end

	if MovementMode == "jog" then
		local JogSpeed = RunSpeedStat * StatBalance.MovementSpeeds.JogSpeedPercent
		return Entity.Modifiers:Apply("Speed", JogSpeed)
	end

	return StatBalance.MovementSpeeds.WalkSpeed
end

local function IsMovementBlocked(Entity: any): boolean
	for _, StateName in MOVEMENT_BLOCKING_STATES do
		if Entity.States:GetState(StateName) then
			return true
		end
	end
	return false
end

local function UpdateMovementSpeed(Entity: any)
	if IsMovementBlocked(Entity) then
		Entity.Humanoid.WalkSpeed = 0
		return
	end

	local CurrentMode = Entity.Character:GetAttribute("MovementMode")
	Entity.Humanoid.WalkSpeed = GetExpectedWalkSpeed(Entity, CurrentMode)
end

local function ClearConflictingStates(Entity: any, StateName: string)
	local Conflicts = CONFLICTING_STATES[StateName]
	if not Conflicts then
		return
	end

	for _, ConflictingState in Conflicts do
		if Entity.States:GetState(ConflictingState) then
			Entity.States:SetState(ConflictingState, false)
		end
	end
end

local function SetupStateHandlers(Entity: any)
	Entity.States:OnStateChanged(StateTypes.STUNNED, function(_IsStunned: boolean)
		UpdateMovementSpeed(Entity)
	end)

	Entity.States:OnStateChanged(StateTypes.RAGDOLLED, function(_IsRagdolled: boolean)
		UpdateMovementSpeed(Entity)
	end)

	Entity.States:OnStateChanged(StateTypes.ATTACKING, function(_IsAttacking: boolean)
		UpdateMovementSpeed(Entity)
	end)

	Entity.States:OnStateChanged(StateTypes.DASHING, function(_IsDashing: boolean)
		UpdateMovementSpeed(Entity)
	end)

	Entity.States:OnStateChanged(StateTypes.INVULNERABLE, function(IsInvulnerable: boolean)
		if IsInvulnerable then
			if not Entity.Character:FindFirstChildOfClass("ForceField") then
				local ForceField = Instance.new("ForceField")
				ForceField.Parent = Entity.Character
			end
		else
			local ExistingForceField = Entity.Character:FindFirstChildOfClass("ForceField")
			if ExistingForceField then
				ExistingForceField:Destroy()
			end
		end
	end)
end

EventBus.Subscribe(EntityEvents.ENTITY_CREATED, function(EventData)
	local Entity = EventData.Entity
	if not Entity.IsPlayer then
		return
	end

	SetupStateHandlers(Entity)
end)

EventBus.Subscribe(EntityEvents.STATE_CHANGED, function(EventData)
	local Entity = EventData.Entity
	local StateName = EventData.StateName
	local Value = EventData.Value

	if Value then
		ClearConflictingStates(Entity, StateName)
	end
end)

return StateHandlers
