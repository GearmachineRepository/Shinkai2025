--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local Packets = require(Shared.Networking.Packets)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

local StateHandlerComponent = {}
StateHandlerComponent.__index = StateHandlerComponent

StateHandlerComponent.ComponentName = "StateHandler"
StateHandlerComponent.Dependencies = { "States" }

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
}

local CONFLICTING_STATES = {
	[StateTypes.STUNNED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DODGING },
	[StateTypes.RAGDOLLED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.STUNNED },
	[StateTypes.ATTACKING] = { StateTypes.BLOCKING, StateTypes.DODGING },
	[StateTypes.BLOCKING] = { StateTypes.ATTACKING, StateTypes.DODGING },
	[StateTypes.DODGING] = { StateTypes.ATTACKING, StateTypes.BLOCKING },
	[StateTypes.DOWNED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.SPRINTING },
}

local MOVEMENT_BLOCKING_STATES = {
	StateTypes.STUNNED,
	StateTypes.RAGDOLLED,
	StateTypes.DOWNED,
}

local ANIMATION_REACTIONS = {
	[StateTypes.STUNNED] = {
		AnimationName = "Stunned",
		FadeTime = 0.25,
		Priority = Enum.AnimationPriority.Action,
		Looped = true,
	},
	[StateTypes.RAGDOLLED] = {
		AnimationName = "Ragdoll",
		FadeTime = 0.1,
		Priority = Enum.AnimationPriority.Action4,
		Looped = false,
	},
	[StateTypes.BLOCKING] = {
		AnimationName = "Block",
		FadeTime = 0.15,
		Priority = Enum.AnimationPriority.Action,
		Looped = true,
	},
}

local VFX_REACTIONS = {
	[StateTypes.STUNNED] = "StunStars",
	[StateTypes.GUARD_BROKEN] = "ShieldBreak",
	[StateTypes.PARRIED] = "ParryFlash",
}

local SFX_REACTIONS = {
	[StateTypes.GUARD_BROKEN] = "ShieldBreakSound",
	[StateTypes.PARRIED] = "ParrySound",
}

local function SetupConflictResolution(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, ConflictingStates in CONFLICTING_STATES do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if not Enabled then
				return
			end

			for _, ConflictingState in ConflictingStates do
				if Entity.States:GetState(ConflictingState) then
					Entity.States:SetState(ConflictingState, false)
				end
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupMovementLocking(Entity: Types.Entity, ComponentMaid: Types.Maid)
	local function UpdateMovementLock()
		local IsLocked = false

		for _, StateName in MOVEMENT_BLOCKING_STATES do
			if Entity.States:GetState(StateName) then
				IsLocked = true
				break
			end
		end

		Entity.States:SetState(StateTypes.MOVEMENT_LOCKED, IsLocked)
	end

	for _, StateName in MOVEMENT_BLOCKING_STATES do
		local Connection = Entity.States:OnStateChanged(StateName, UpdateMovementLock)
		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupForceField(Entity: Types.Entity, ComponentMaid: Types.Maid)
	local Connection = Entity.States:OnStateChanged(StateTypes.INVULNERABLE, function(IsInvulnerable: boolean)
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

	ComponentMaid:GiveTask(Connection)
end

local function SetupAnimationReactions(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, AnimConfig in ANIMATION_REACTIONS do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if not Entity.Player then
				return
			end

			local AnimationId = AnimationDatabase[AnimConfig.AnimationName]
			if not AnimationId then
				warn("Animation not found:", AnimConfig.AnimationName)
				return
			end

			if Enabled then
				local Options = {
					FadeTime = AnimConfig.FadeTime,
					Priority = AnimConfig.Priority,
					Looped = AnimConfig.Looped,
				}
				Packets.PlayAnimation:FireClient(Entity.Player, AnimationId, Options)
			else
				Packets.StopAnimation:FireClient(Entity.Player, AnimationId, AnimConfig.FadeTime)
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupVFXReactions(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, VfxName in VFX_REACTIONS do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if Enabled and Entity.Player then
                local PrimaryPart = Entity.Character.PrimaryPart
                if not PrimaryPart then return end
				Packets.PlayVfx:FireClient(Entity.Player, VfxName, {
					CFrame = PrimaryPart.CFrame,
				})
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupSFXReactions(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, SfxName in SFX_REACTIONS do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if Enabled and Entity.Player then
				Packets.PlaySound:FireClient(Entity.Player, SfxName)
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

function StateHandlerComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
	}, StateHandlerComponent) :: any

	SetupConflictResolution(Entity, self.Maid)
	SetupMovementLocking(Entity, self.Maid)
	SetupForceField(Entity, self.Maid)
	SetupAnimationReactions(Entity, self.Maid)
	SetupVFXReactions(Entity, self.Maid)
	SetupSFXReactions(Entity, self.Maid)

	return self
end

function StateHandlerComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return StateHandlerComponent