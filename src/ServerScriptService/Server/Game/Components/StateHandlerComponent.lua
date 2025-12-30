--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)
local CombatEvents = require(Server.Combat.CombatEvents)

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local Packets = require(Shared.Networking.Packets)
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
	[StateTypes.DODGING] = { StateTypes.ATTACKING, StateTypes.BLOCKING },
	[StateTypes.DOWNED] = { StateTypes.ATTACKING, StateTypes.BLOCKING, StateTypes.DODGING, StateTypes.SPRINTING },
}

local MOVEMENT_BLOCKING_STATES = {
	StateTypes.GUARD_BROKEN,
	StateTypes.RAGDOLLED,
	StateTypes.DOWNED,
}

local FORCE_WALK_STATES = {
	StateTypes.STUNNED,
	StateTypes.GUARD_BROKEN,
	StateTypes.EXHAUSTED,
}

local STATE_ANIMATIONS = {
	[StateTypes.RAGDOLLED] = {
		AnimationName = "Ragdoll",
		FadeTime = 0.1,
		Priority = Enum.AnimationPriority.Action4,
		Looped = false,
	},
}

local STATE_VFX = {
	[StateTypes.PARRIED] = "ParryFlash",
}

local STATE_SFX = {
	[StateTypes.PARRIED] = "ParrySound",
}

local COMBAT_VFX: { [string]: (EventData: any) -> (string?, Model?, Vector3?) } = {
	[CombatEvents.AttackHit] = function(EventData)
		return "Hit", EventData.Target and EventData.Target.Character, EventData.HitPosition
	end,
	[CombatEvents.BlockHit] = function(EventData)
		return "BlockHit", EventData.Entity and EventData.Entity.Character, EventData.HitPosition
	end,
	[CombatEvents.ParrySuccess] = function(EventData)
		return "ParryFlash", EventData.Entity and EventData.Entity.Character, nil
	end,
	[CombatEvents.PerfectGuardSuccess] = function(EventData)
		return "PerfectGuardFlash", EventData.Entity and EventData.Entity.Character, nil
	end,
	[CombatEvents.CounterInitiated] = function(EventData)
		return "CounterInitiate", EventData.Entity and EventData.Entity.Character, nil
	end,
	[CombatEvents.PerfectGuardInitiated] = function(EventData)
		return "PerfectGuardinitiate", EventData.Entity and EventData.Entity.Character, nil
	end,
	[CombatEvents.CounterHit] = function(EventData)
		return "Hit", EventData.Target and EventData.Target.Character, nil
	end,
	[CombatEvents.GuardBroken] = function(EventData)
		return "GuardBroken", EventData.Entity and EventData.Entity.Character, nil
	end,
	[CombatEvents.ClashOccurred] = function(EventData)
		return "Clash", EventData.EntityA and EventData.EntityA.Character, nil
	end,
	[CombatEvents.FeintExecuted] = function(EventData)
		return "FeintSmoke", EventData.Entity and EventData.Entity.Character, nil
	end,
	-- [CombatEvents.StunApplied] = function(EventData)
	-- 	return "StunStars", EventData.Entity and EventData.Entity.Character, nil
	-- end,
}

local COMBAT_SFX: { [string]: (EventData: any) -> (string?, Vector3?) } = {
	[CombatEvents.ParrySuccess] = function(_EventData)
		return "ParrySound", nil
	end,
	[CombatEvents.ClashOccurred] = function(_EventData)
		return "ClashSound", nil
	end,
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

local function SetupForceWalk(Entity: Types.Entity, ComponentMaid: Types.Maid)
	local function UpdateForceWalk()
		local ShouldForceWalk = false

		for _, StateName in FORCE_WALK_STATES do
			if Entity.States:GetState(StateName) then
				ShouldForceWalk = true
				break
			end
		end

		if ShouldForceWalk then
			local CurrentMode = Entity.Character:GetAttribute("MovementMode")
			if CurrentMode == "jog" or CurrentMode == "run" then
				Entity.Character:SetAttribute("MovementMode", "walk")
			end
		end
	end

	for _, StateName in FORCE_WALK_STATES do
		local Connection = Entity.States:OnStateChanged(StateName, UpdateForceWalk)
		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupStateAnimations(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, AnimationData in STATE_ANIMATIONS do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			local Player = Entity.Player
			if not Player then
				return
			end

			if Enabled then
				Packets.PlayAnimation:FireClient(Player, AnimationData.AnimationName)
			else
				Packets.StopAnimation:FireClient(Player, AnimationData.AnimationName, AnimationData.FadeTime or 0.1)
			end
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupStateVfx(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, VfxName in STATE_VFX do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if not Enabled then
				return
			end

			Packets.PlayVfxReplicate:Fire(Entity.Player or Entity.Character, VfxName, {
				Target = Entity.Character,
			})
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupStateSfx(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for StateName, SfxName in STATE_SFX do
		local Connection = Entity.States:OnStateChanged(StateName, function(Enabled: boolean)
			if not Enabled then
				return
			end

			local RootPart = Entity.Character and Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local Position = RootPart and RootPart.Position

			Packets.PlaySoundReplicate:Fire(Entity.Player or Entity.Character, SfxName, {
				Position = Position,
			})
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupCombatEventReactions(Entity: Types.Entity, ComponentMaid: Types.Maid)
	for EventName, VfxGetter in COMBAT_VFX do
		local Connection = Ensemble.Events.Subscribe(EventName, function(EventData: any)
			local EventEntity = EventData.Entity or EventData.EntityA
			if EventEntity ~= Entity then
				return
			end

			local VfxName, TargetCharacter, Position = VfxGetter(EventData)
			if not VfxName then
				return
			end

			Packets.PlayVfxReplicate:Fire(Entity.Player or Entity.Character, VfxName, {
				Target = TargetCharacter,
				HitPosition = Position,
			})
		end)

		ComponentMaid:GiveTask(Connection)
	end

	for EventName, SfxGetter in COMBAT_SFX do
		local Connection = Ensemble.Events.Subscribe(EventName, function(EventData: any)
			local EventEntity = EventData.Entity or EventData.EntityA
			if EventEntity ~= Entity then
				return
			end

			local SfxName, Position = SfxGetter(EventData)
			if not SfxName then
				return
			end

			if not Position then
				local RootPart = Entity.Character and Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				Position = RootPart and RootPart.Position
			end

			Packets.PlaySoundReplicate:Fire(Entity.Player or Entity.Character, SfxName, {
				Position = Position,
			})
		end)

		ComponentMaid:GiveTask(Connection)
	end
end

local function SetupForceField(Entity: Types.Entity, ComponentMaid: Types.Maid)
	local Connection = Entity.States:OnStateChanged(StateTypes.INVULNERABLE, function(IsInvulnerable: boolean)
		if IsInvulnerable then
			if not Entity.Character:FindFirstChildOfClass("ForceField") then
				local ForceField = Instance.new("ForceField")
				ForceField.Visible = false
				ForceField.Parent = Entity.Character
			end
		else
			local ForceField = Entity.Character:FindFirstChildOfClass("ForceField")
			if ForceField then
				ForceField:Destroy()
			end
		end
	end)

	ComponentMaid:GiveTask(Connection)
end

function StateHandlerComponent.new(Entity: Types.Entity, _Context: any): Self
	local ComponentMaid = Ensemble.Maid.new()

	SetupConflictResolution(Entity, ComponentMaid)
	SetupMovementLocking(Entity, ComponentMaid)
	SetupForceWalk(Entity, ComponentMaid)
	SetupStateAnimations(Entity, ComponentMaid)
	SetupStateVfx(Entity, ComponentMaid)
	SetupStateSfx(Entity, ComponentMaid)
	SetupCombatEventReactions(Entity, ComponentMaid)
	SetupForceField(Entity, ComponentMaid)

	local self: Self = setmetatable({
		Entity = Entity,
		Maid = ComponentMaid,
	}, StateHandlerComponent) :: any

	return self
end

function StateHandlerComponent:Destroy()
	self.Maid:DoCleaning()
end

return StateHandlerComponent