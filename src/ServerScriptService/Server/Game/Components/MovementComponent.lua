--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)
local ActionValidator = require(Shared.Utils.ActionValidator)

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local StaminaBalance = require(Shared.Configurations.Balance.StaminaBalance)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local Formulas = require(Shared.General.Formulas)

local MovementComponent = {}
MovementComponent.__index = MovementComponent

MovementComponent.ComponentName = "Movement"
MovementComponent.Dependencies = { "Stats", "Stamina" }
MovementComponent.UpdateRate = 1 / 60

local WALKSPEED_UPDATE_THROTTLE = 0.05

local MODE_TO_ACTION = {
	jog = "Jog",
	run = "Run",
}

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	LastWalkSpeedUpdate: number,
	LastSprintEndTime: number,
	SprintStartTime: number?,
}

function MovementComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		LastWalkSpeedUpdate = 0,
		LastSprintEndTime = 0,
		SprintStartTime = nil,
	}, MovementComponent) :: any

	local Connection = Entity.Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		local CurrentMode = Entity.Character:GetAttribute("MovementMode") :: string?
		if CurrentMode then
			MovementComponent.SetMovementMode(self, CurrentMode)
		end
	end)

	self.Maid:GiveTask(Connection)

	return self
end

function MovementComponent.GetWalkSpeed(_self: Self): number
	return StatBalance.MovementSpeeds.WalkSpeed
end

function MovementComponent.GetTargetSprintSpeed(self: Self, Mode: string?): number
	local CurrentMode = Mode or self.Entity.Character:GetAttribute("MovementMode")
	local RunSpeedStat = self.Entity.Stats:GetStat(StatTypes.RUN_SPEED)

	if CurrentMode == "run" then
		return RunSpeedStat
	end

	if CurrentMode == "jog" then
		return RunSpeedStat * StatBalance.MovementSpeeds.JogSpeedPercent
	end

	return StatBalance.MovementSpeeds.WalkSpeed
end

function MovementComponent.GetSprintRampProgress(self: Self): number
	if not self.SprintStartTime then
		return 1
	end

	local CurrentTime = os.clock()
	local TimeSinceStart = CurrentTime - self.SprintStartTime
	local RampDuration = StaminaBalance.Sprint.RAMP_DURATION_SECONDS

	return math.clamp(TimeSinceStart / RampDuration, 0, 1)
end

function MovementComponent.GetBaseSpeed(self: Self, Mode: string?): number
	local CurrentMode = Mode or self.Entity.Character:GetAttribute("MovementMode")

	if CurrentMode == "walk" then
		return MovementComponent.GetWalkSpeed(self)
	end

	local WalkSpeed = MovementComponent.GetWalkSpeed(self)
	local TargetSpeed = MovementComponent.GetTargetSprintSpeed(self, CurrentMode :: string)
	local RampProgress = MovementComponent.GetSprintRampProgress(self)

	return WalkSpeed + (TargetSpeed - WalkSpeed) * RampProgress
end

function MovementComponent.GetCurrentSpeed(self: Self): number
	if self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED) then
		return 0
	end

	local BaseSpeed = MovementComponent.GetBaseSpeed(self)
	return self.Entity.Modifiers:Apply("WalkSpeed", BaseSpeed)
end

function MovementComponent.EnforceWalkSpeed(self: Self)
	local Now = os.clock()
	if Now - self.LastWalkSpeedUpdate < WALKSPEED_UPDATE_THROTTLE then
		return
	end

	local ExpectedSpeed = MovementComponent.GetCurrentSpeed(self)

	if not Formulas.IsNearlyEqual(self.Entity.Humanoid.WalkSpeed, ExpectedSpeed, 0.1) then
		self.Entity.Humanoid.WalkSpeed = ExpectedSpeed
	end

	self.LastWalkSpeedUpdate = Now
end

function MovementComponent.IsOnSprintCooldown(self: Self): boolean
	local CurrentTime = os.clock()
	local CooldownDuration = StaminaBalance.Sprint.COOLDOWN_SECONDS
	local TimeSinceEnd = CurrentTime - self.LastSprintEndTime

	return TimeSinceEnd < CooldownDuration
end

function MovementComponent.GetSprintCooldownRemaining(self: Self): number
	local CurrentTime = os.clock()
	local CooldownDuration = StaminaBalance.Sprint.COOLDOWN_SECONDS
	local TimeSinceEnd = CurrentTime - self.LastSprintEndTime

	return math.max(0, CooldownDuration - TimeSinceEnd)
end

function MovementComponent.CanStartSprinting(self: Self): boolean
	if self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED) then
		return false
	end

	local ActionName = MODE_TO_ACTION["run"]
	local CanPerform, _Reason = ActionValidator.CanPerform(self.Entity.States, ActionName)
	if not CanPerform then
		return false
	end

	if MovementComponent.IsOnSprintCooldown(self) then
		return false
	end

	local Stamina = self.Entity:GetComponent("Stamina") :: any
	if not Stamina then
		return false
	end

	return Stamina:CanSprint()
end

function MovementComponent.CanStartJogging(self: Self): boolean
	if self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED) then
		return false
	end

	local ActionName = MODE_TO_ACTION["jog"]
	local CanPerform, _Reason = ActionValidator.CanPerform(self.Entity.States, ActionName)
	if not CanPerform then
		return false
	end

	if MovementComponent.IsOnSprintCooldown(self) then
		return false
	end

	local Stamina = self.Entity:GetComponent("Stamina") :: any
	if not Stamina then
		return false
	end

	return Stamina:CanJog()
end

function MovementComponent.ValidateMovementMode(self: Self, Mode: string): boolean
	if Mode == "walk" then
		return true
	end

	if Mode == "run" then
		return MovementComponent.CanStartSprinting(self)
	end

	if Mode == "jog" then
		return MovementComponent.CanStartJogging(self)
	end

	return false
end

function MovementComponent.SetMovementMode(self: Self, Mode: string)
	if self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED) then
		return
	end

	local PreviousMode = self.Entity.Character:GetAttribute("MovementMode")
	local WasSprinting = PreviousMode == "run" or PreviousMode == "jog"

	if Mode == "run" then
		MovementComponent.HandleSprintMode(self)
	elseif Mode == "jog" then
		MovementComponent.HandleJogMode(self)
	else
		if WasSprinting then
			self.LastSprintEndTime = os.clock()
		end
		MovementComponent.HandleWalkMode(self)
	end
end

function MovementComponent.HandleSprintMode(self: Self)
	self.SprintStartTime = os.clock()

	self.Entity.States:SetState(StateTypes.SPRINTING, true)
	self.Entity.States:SetState(StateTypes.JOGGING, false)

	local Stamina = self.Entity:GetComponent("Stamina") :: any
	if Stamina then
		Stamina:OnSprintStart()
	end
end

function MovementComponent.HandleJogMode(self: Self)
	self.SprintStartTime = os.clock()

	self.Entity.States:SetState(StateTypes.JOGGING, true)
	self.Entity.States:SetState(StateTypes.SPRINTING, false)

	local Stamina = self.Entity:GetComponent("Stamina") :: any
	if Stamina then
		Stamina:OnJogStart()
	end
end

function MovementComponent.HandleWalkMode(self: Self)
	self.SprintStartTime = nil

	local WasSprinting = self.Entity.States:GetState(StateTypes.SPRINTING)
	local WasJogging = self.Entity.States:GetState(StateTypes.JOGGING)

	local Stamina = self.Entity:GetComponent("Stamina") :: any
	if Stamina then
		if WasSprinting then
			Stamina:OnSprintEnd()
		end

		if WasJogging then
			Stamina:OnJogEnd()
		end
	end

	self.Entity.States:SetState(StateTypes.SPRINTING, false)
	self.Entity.States:SetState(StateTypes.JOGGING, false)
end

function MovementComponent.UpdateStaminaAndTraining(self: Self, DeltaTime: number)
	if self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED) then
		return
	end

	local Stamina = self.Entity:GetComponent("Stamina") :: any
	if not Stamina then
		return
	end

	local CurrentMode = self.Entity.Character:GetAttribute("MovementMode")
	local PrimaryPart = self.Entity.Character.PrimaryPart

	local IsMoving = false
	if PrimaryPart then
		IsMoving = PrimaryPart.AssemblyLinearVelocity.Magnitude > 1
	end

	local CanContinue = Stamina:Update(DeltaTime, CurrentMode, IsMoving)

	local Training = self.Entity:GetComponent("Training") :: any
	if CanContinue and IsMoving and Training then
		if CurrentMode == "run" then
			local RunSpeedXP = (
				TrainingBalance.TrainingTypes.RunSpeed.BaseXPPerSecond
				* TrainingBalance.TrainingTypes.RunSpeed.NonmachineMultiplier
			) * DeltaTime
			local FatigueGain = 0.35
			Training:GrantStatGain(StatTypes.RUN_SPEED, RunSpeedXP, FatigueGain)
		elseif CurrentMode == "jog" then
			local StaminaXP = (
				TrainingBalance.TrainingTypes.Stamina.BaseXPPerSecond
				* TrainingBalance.TrainingTypes.Stamina.NonmachineMultiplier
			) * DeltaTime
			local FatigueGain = 0.4
			Training:GrantStatGain(StatTypes.MAX_STAMINA, StaminaXP, FatigueGain)
		end
	end

	if not CanContinue and CurrentMode ~= "walk" then
		self.LastSprintEndTime = os.clock()
		self.Entity.Character:SetAttribute("MovementMode", "walk")
	end
end

function MovementComponent.Update(self: Self, DeltaTime: number)
	MovementComponent.UpdateStaminaAndTraining(self, DeltaTime)
	MovementComponent.EnforceWalkSpeed(self)
end

function MovementComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return MovementComponent