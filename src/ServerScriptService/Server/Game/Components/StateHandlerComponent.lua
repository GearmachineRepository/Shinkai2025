--!strict

--local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local Packets = require(Shared.Networking.Packets)
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)

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
	[StateTypes.ATTACKING] = { StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.SPRINTING, StateTypes.JOGGING },
	--[StateTypes.BLOCKING] = { StateTypes.ATTACKING, StateTypes.DODGING },
	[StateTypes.DODGING] = { StateTypes.ATTACKING, StateTypes.BLOCKING },
	[StateTypes.DOWNED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.SPRINTING },
}

local MOVEMENT_BLOCKING_STATES = {
	--StateTypes.STUNNED,
	StateTypes.GUARD_BROKEN,
	StateTypes.RAGDOLLED,
	StateTypes.DOWNED,
}

local FORCE_WALK_STATES = {
	StateTypes.STUNNED,
	StateTypes.GUARD_BROKEN,
	StateTypes.EXHAUSTED,
}

local ANIMATION_REACTIONS = {
	-- [StateTypes.STUNNED] = {
	-- 	AnimationName = "Stunned",
	-- 	FadeTime = 0.25,
	-- 	Priority = Enum.AnimationPriority.Action,
	-- 	Looped = true,
	-- },
	[StateTypes.RAGDOLLED] = {
		AnimationName = "Ragdoll",
		FadeTime = 0.1,
		Priority = Enum.AnimationPriority.Action4,
		Looped = false,
	},
	-- [StateTypes.BLOCKING] = {
	-- 	AnimationName = "Block",
	-- 	FadeTime = 0.15,
	-- 	Priority = Enum.AnimationPriority.Action,
	-- 	Looped = true,
	-- },
}

local VFX_REACTIONS = {
	--[StateTypes.STUNNED] = "StunStars",
	[StateTypes.GUARD_BROKEN] = "GuardBroken",
	[StateTypes.PARRIED] = "ParryFlash",
	--[StateTypes.ONHIT] = "Hit",
	--[StateTypes.BLOCK_HIT] = "BlockHit"
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

local function CanJump(Entity: Types.Entity, Toggle: boolean)
	local JumpPower = if not Toggle then StatBalance.Defaults.JumpPower else 0
	local Character = Entity.Character
	if Character then
		local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
		if Humanoid then
			Humanoid.JumpPower = JumpPower
		end
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

		CanJump(Entity, IsLocked)

		Entity.States:SetState(StateTypes.MOVEMENT_LOCKED, IsLocked)
	end

	for _, StateName in MOVEMENT_BLOCKING_STATES do
		local Connection = Entity.States:OnStateChanged(StateName, UpdateMovementLock)
		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupAttackingMovementRestriction(Entity: Types.Entity, ComponentMaid: Types.Maid)
	local Connection = Entity.States:OnStateChanged(StateTypes.ATTACKING, function(IsAttacking: boolean)
		if IsAttacking then
			local CurrentMode = Entity.Character:GetAttribute("MovementMode")
			if CurrentMode == "jog" or CurrentMode == "run" then
				Entity.Character:SetAttribute("MovementMode", "walk")
			end
		end
	end)

	ComponentMaid:GiveTask(Connection)
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
	for StateName, VfxName in pairs(VFX_REACTIONS) do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if Enabled then
				local SendingCharacter = if Entity.IsPlayer and Entity.Player then Entity.Player.UserId else Entity.Character :: any
				Packets.PlayVfxReplicate:Fire(SendingCharacter, VfxName, { Target = Entity.Character })
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupSFXReactions(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, SoundName in SFX_REACTIONS do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if Enabled and Entity.Player then
				Packets.PlaySound:FireClient(Entity.Player, SoundName, { Target = Entity.Character })
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupForceWalkOnStates(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for _, StateName in FORCE_WALK_STATES do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if not Enabled then
				return
			end

			local Character = Entity.Character
			if not Character then
				return
			end

			local CurrentMode = Character:GetAttribute("MovementMode")
			if CurrentMode and CurrentMode ~= "walk" then
				Character:SetAttribute("MovementMode", "walk")
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupStunnedSpeedModifier(Entity: Types.Entity, ComponentMaid: Types.Maid)
	local RemoveModifier: (() -> ())? = nil

	local Connection = Entity.States:OnStateChanged(StateTypes.STUNNED, function(Enabled: boolean)
		CanJump(Entity, Enabled)

		if Enabled then
			local Multiplier = CombatBalance.Stunned.MOVEMENT_SPEED_MULTIPLIER or 0.3
			RemoveModifier = Entity.Modifiers:Register("WalkSpeed", 50, function(Value: number)
				return Value * Multiplier
			end)
		elseif RemoveModifier then
			RemoveModifier()
			RemoveModifier = nil
		end
	end)

	ComponentMaid:GiveTask(Connection)
	ComponentMaid:GiveTask(function()
		if RemoveModifier then
			RemoveModifier()
		end
	end)
end

function StateHandlerComponent.new(Entity: Types.Entity): Types.Component
	local ComponentMaid = Ensemble.Maid.new()

	SetupConflictResolution(Entity, ComponentMaid)
	SetupMovementLocking(Entity, ComponentMaid)
	SetupAttackingMovementRestriction(Entity, ComponentMaid)
	SetupForceField(Entity, ComponentMaid)
	SetupAnimationReactions(Entity, ComponentMaid)
	SetupVFXReactions(Entity, ComponentMaid)
	SetupSFXReactions(Entity, ComponentMaid)
	SetupForceWalkOnStates(Entity, ComponentMaid)
	SetupStunnedSpeedModifier(Entity, ComponentMaid)

	local self: Self = {
		Entity = Entity,
		Maid = ComponentMaid,
		LastUpdate = workspace:GetServerTimeNow()
	}

	setmetatable(self, StateHandlerComponent)

	return self :: any
end

function StateHandlerComponent:Destroy()
	self.Maid:DoCleaning()
end

return StateHandlerComponent