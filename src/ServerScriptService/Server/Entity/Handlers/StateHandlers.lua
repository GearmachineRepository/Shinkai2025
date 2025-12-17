--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)

local StateHandlers = {}

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

local function SetupStateHandlers(Entity: any)
	Entity.States:OnStateChanged(StateTypes.RAGDOLLED, function(IsRagdolled: boolean)
		if IsRagdolled then
			return
		end
	end)

	Entity.States:OnStateChanged(StateTypes.STUNNED, function(IsStunned: boolean)
		if IsStunned then
			Entity.Humanoid.WalkSpeed = 0
			return
		end

		local CurrentMode = Entity.Character:GetAttribute("MovementMode")
		Entity.Humanoid.WalkSpeed = GetExpectedWalkSpeed(Entity, CurrentMode)
	end)

	Entity.States:OnStateChanged(StateTypes.ATTACKING, function(IsAttacking: boolean)
		if IsAttacking then
			return
		end
	end)

	Entity.States:OnStateChanged(StateTypes.INVULNERABLE, function(IsInvulnerable: boolean)
		if IsInvulnerable then
			if not Entity.Character:FindFirstChildOfClass("ForceField") then
				local ForceField = Instance.new("ForceField")
				ForceField.Parent = Entity.Character
			end
			return
		end

		local ExistingForceField = Entity.Character:FindFirstChildOfClass("ForceField")
		if ExistingForceField then
			ExistingForceField:Destroy()
		end
	end)

	Entity.States:OnStateChanged(StateTypes.BLOCKING, function(IsBlocking: boolean)
		if IsBlocking then
			Entity.Character:SetAttribute("IsBlocking", true)
		else
			Entity.Character:SetAttribute("IsBlocking", false)
		end
	end)

	Entity.States:OnStateChanged(StateTypes.PARRYING, function(IsParrying: boolean)
		if IsParrying then
			Entity.Character:SetAttribute("IsParrying", true)
		else
			Entity.Character:SetAttribute("IsParrying", false)
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

return StateHandlers
