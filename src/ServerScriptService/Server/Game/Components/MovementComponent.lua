--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local Maid = require(Shared.General.Maid)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local Formulas = require(Shared.General.Formulas)

export type MovementComponent = {
	Entity: any,
	Update: (self: MovementComponent, DeltaTime: number) -> (),
	SetMovementMode: (self: MovementComponent, Mode: string) -> (),
	GetCurrentSpeed: (self: MovementComponent) -> number,
	Destroy: (self: MovementComponent) -> (),
}

type MovementComponentInternal = MovementComponent & {
	Maid: Maid.MaidSelf,
	LastWalkSpeedUpdate: number,
}

local MovementComponent = {}
MovementComponent.__index = MovementComponent

local WALKSPEED_UPDATE_THROTTLE = 0.05

function MovementComponent.new(Entity: any): MovementComponent
	local self: MovementComponentInternal = setmetatable({
		Entity = Entity,
		Maid = Maid.new(),
		LastWalkSpeedUpdate = 0,
	}, MovementComponent) :: any

	self:SetupMovementTracking()

	return self
end

function MovementComponent:SetupMovementTracking()
	local Connection = self.Entity.Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		local CurrentMode = self.Entity.Character:GetAttribute("MovementMode")
		self:SetMovementMode(CurrentMode)
	end)

	self.Maid:GiveTask(Connection)
end

function MovementComponent:GetBaseSpeed(Mode: string?): number
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

function MovementComponent:GetCurrentSpeed(): number
	if
		self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED)
		or self.Entity.States:GetState(StateTypes.REQUIRE_MOVE_REINTENT)
	then
		return 0
	end

	local BaseSpeed = self:GetBaseSpeed()
	return self.Entity.Modifiers:Apply("WalkSpeed", BaseSpeed)
end

function MovementComponent:EnforceWalkSpeed()
	local Now = os.clock()
	if Now - self.LastWalkSpeedUpdate < WALKSPEED_UPDATE_THROTTLE then
		return
	end

	local ExpectedSpeed = self:GetCurrentSpeed()

	if not Formulas.IsNearlyEqual(self.Entity.Humanoid.WalkSpeed, ExpectedSpeed, 0.1) then
		self.Entity.Humanoid.WalkSpeed = ExpectedSpeed
	end

	self.LastWalkSpeedUpdate = Now
end

function MovementComponent:SetMovementMode(Mode: string)
	if
		self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED)
		or self.Entity.States:GetState(StateTypes.REQUIRE_MOVE_REINTENT)
	then
		return
	end

	if Mode == "run" then
		self:HandleSprintMode()
	elseif Mode == "jog" then
		self:HandleJogMode()
	else
		self:HandleWalkMode()
	end
end

function MovementComponent:HandleSprintMode()
	self.Entity.States:SetState(StateTypes.SPRINTING, true)
	self.Entity.States:SetState(StateTypes.JOGGING, false)

	if self.Entity.Components.Stamina then
		self.Entity.Components.Stamina:OnSprintStart()
	end
end

function MovementComponent:HandleJogMode()
	self.Entity.States:SetState(StateTypes.JOGGING, true)
	self.Entity.States:SetState(StateTypes.SPRINTING, false)

	if self.Entity.Components.Stamina then
		self.Entity.Components.Stamina:OnJogStart()
	end
end

function MovementComponent:HandleWalkMode()
	local WasSprinting = self.Entity.States:GetState(StateTypes.SPRINTING)
	local WasJogging = self.Entity.States:GetState(StateTypes.JOGGING)

	if self.Entity.Components.Stamina then
		if WasSprinting then
			self.Entity.Components.Stamina:OnSprintEnd()
		end

		if WasJogging then
			self.Entity.Components.Stamina:OnJogEnd()
		end
	end

	self.Entity.States:SetState(StateTypes.SPRINTING, false)
	self.Entity.States:SetState(StateTypes.JOGGING, false)
end

function MovementComponent:UpdateStaminaAndTraining(DeltaTime: number)
	if self.Entity.States:GetState(StateTypes.MOVEMENT_LOCKED) then
		return
	end
	if not self.Entity.Components.Stamina then
		return
	end

	local CurrentMode = self.Entity.Character:GetAttribute("MovementMode")
	local PrimaryPart = self.Entity.Character.PrimaryPart

	local IsMoving = false
	if PrimaryPart then
		IsMoving = PrimaryPart.AssemblyLinearVelocity.Magnitude > 1
	end

	local CanContinue = self.Entity.Components.Stamina:Update(DeltaTime, CurrentMode, IsMoving)

	if CanContinue and IsMoving and self.Entity.Components.Training then
		if CurrentMode == "run" then
			local RunSpeedXP = (
				TrainingBalance.TrainingTypes.RunSpeed.BaseXPPerSecond
				* TrainingBalance.TrainingTypes.RunSpeed.NonmachineMultiplier
			) * DeltaTime
			local FatigueGain = 0.35
			self.Entity.Components.Training:GrantStatGain(StatTypes.RUN_SPEED, RunSpeedXP, FatigueGain)
		elseif CurrentMode == "jog" then
			local StaminaXP = (
				TrainingBalance.TrainingTypes.Stamina.BaseXPPerSecond
				* TrainingBalance.TrainingTypes.Stamina.NonmachineMultiplier
			) * DeltaTime
			local FatigueGain = 0.4
			self.Entity.Components.Training:GrantStatGain(StatTypes.MAX_STAMINA, StaminaXP, FatigueGain)
		end
	end

	if not CanContinue and CurrentMode ~= "walk" then
		self.Entity.Character:SetAttribute("MovementMode", "walk")
	end
end

function MovementComponent:Update(DeltaTime: number)
	self:UpdateStaminaAndTraining(DeltaTime)
	self:EnforceWalkSpeed()
end

function MovementComponent:Destroy()
	self.Maid:DoCleaning()
end

return MovementComponent
