--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local UpdateService = require(Shared.Networking.UpdateService)
local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local Formulas = require(Shared.General.Formulas)

local EntityUpdateSystem = {}

local WALKSPEED_UPDATE_THROTTLE = 0.05
local MOVEMENT_TICK_RATE = 0.10

local EntityUpdateData: {
	[any]: {
		LastWalkSpeedUpdate: number,
		MovementTickAccumulator: number,
	},
} = {}

local function GetExpectedWalkSpeed(EntityInstance: any, MovementMode: string?): number
	local RunSpeedStat = EntityInstance.Stats:GetStat(StatTypes.RUN_SPEED)

	if MovementMode == "run" then
		return EntityInstance.Modifiers:Apply("Speed", RunSpeedStat)
	end

	if MovementMode == "jog" then
		local JogSpeed = RunSpeedStat * StatBalance.MovementSpeeds.JogSpeedPercent
		return EntityInstance.Modifiers:Apply("Speed", JogSpeed)
	end

	return StatBalance.MovementSpeeds.WalkSpeed
end

local function EnforceWalkSpeed(EntityInstance: any)
	local UpdateData = EntityUpdateData[EntityInstance]
	if not UpdateData then
		return
	end

	local Now = os.clock()
	if Now - UpdateData.LastWalkSpeedUpdate < WALKSPEED_UPDATE_THROTTLE then
		return
	end

	local CurrentMode = EntityInstance.Character:GetAttribute("MovementMode")
	local ExpectedSpeed = GetExpectedWalkSpeed(EntityInstance, CurrentMode)

	if not Formulas.IsNearlyEqual(EntityInstance.Humanoid.WalkSpeed, ExpectedSpeed, 0.1) then
		EntityInstance.Humanoid.WalkSpeed = ExpectedSpeed
	end

	UpdateData.LastWalkSpeedUpdate = Now
end

local function UpdateStaminaAndMovement(EntityInstance: any, DeltaTime: number)
	if not EntityInstance.Components.Stamina then
		return
	end

	local UpdateData = EntityUpdateData[EntityInstance]
	if not UpdateData then
		return
	end

	local CurrentMode = EntityInstance.Character:GetAttribute("MovementMode")
	local PrimaryPart = EntityInstance.Character.PrimaryPart

	local IsMoving = false
	if PrimaryPart then
		IsMoving = PrimaryPart.AssemblyLinearVelocity.Magnitude > 1
	end

	UpdateData.MovementTickAccumulator += DeltaTime
	if UpdateData.MovementTickAccumulator < MOVEMENT_TICK_RATE then
		return
	end

	local AppliedDeltaTime = UpdateData.MovementTickAccumulator
	UpdateData.MovementTickAccumulator = 0

	local CanContinue = EntityInstance.Components.Stamina:Update(AppliedDeltaTime, CurrentMode, IsMoving)

	if CanContinue and IsMoving and EntityInstance.Components.Training then
		if CurrentMode == "run" then
			local RunSpeedXP = (
				TrainingBalance.TrainingTypes.RunSpeed.BaseXPPerSecond
				* TrainingBalance.TrainingTypes.RunSpeed.NonmachineMultiplier
			) * AppliedDeltaTime
			local FatigueGain = 0.35
			EntityInstance.Components.Training:GrantStatGain(StatTypes.RUN_SPEED, RunSpeedXP, FatigueGain)
		elseif CurrentMode == "jog" then
			local StaminaXP = (
				TrainingBalance.TrainingTypes.Stamina.BaseXPPerSecond
				* TrainingBalance.TrainingTypes.Stamina.NonmachineMultiplier
			) * AppliedDeltaTime
			local FatigueGain = 0.4
			EntityInstance.Components.Training:GrantStatGain(StatTypes.MAX_STAMINA, StaminaXP, FatigueGain)
		end
	end

	if not CanContinue and CurrentMode ~= "walk" then
		EntityInstance.Character:SetAttribute("MovementMode", "walk")
	end
end

local function HandleSprintMode(EntityInstance: any)
	EntityInstance.States:SetState(StateTypes.SPRINTING, true)
	EntityInstance.States:SetState(StateTypes.JOGGING, false)

	if EntityInstance.Components.Stamina then
		EntityInstance.Components.Stamina:OnSprintStart()
	end

	local UpdateData = EntityUpdateData[EntityInstance]
	if UpdateData then
		UpdateData.MovementTickAccumulator = 0
	end
end

local function HandleJogMode(EntityInstance: any)
	EntityInstance.States:SetState(StateTypes.JOGGING, true)
	EntityInstance.States:SetState(StateTypes.SPRINTING, false)

	if EntityInstance.Components.Stamina then
		EntityInstance.Components.Stamina:OnJogStart()
	end

	local UpdateData = EntityUpdateData[EntityInstance]
	if UpdateData then
		UpdateData.MovementTickAccumulator = 0
	end
end

local function HandleWalkMode(EntityInstance: any)
	local WasSprinting = EntityInstance.States:GetState(StateTypes.SPRINTING)
	local WasJogging = EntityInstance.States:GetState(StateTypes.JOGGING)

	if EntityInstance.Components.Stamina then
		if WasSprinting then
			EntityInstance.Components.Stamina:OnSprintEnd()
		end
		if WasJogging then
			EntityInstance.Components.Stamina:OnJogEnd()
		end
	end

	EntityInstance.States:SetState(StateTypes.SPRINTING, false)
	EntityInstance.States:SetState(StateTypes.JOGGING, false)

	local UpdateData = EntityUpdateData[EntityInstance]
	if UpdateData then
		UpdateData.MovementTickAccumulator = 0
	end
end

local function SetupMovementTracking(EntityInstance: any)
	if not EntityInstance.IsPlayer or not EntityInstance.Components.Stamina then
		return
	end

	EntityInstance.Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		local CurrentMode = EntityInstance.Character:GetAttribute("MovementMode")

		if CurrentMode == "run" then
			HandleSprintMode(EntityInstance)
		elseif CurrentMode == "jog" then
			HandleJogMode(EntityInstance)
		else
			HandleWalkMode(EntityInstance)
		end
	end)
end

EventBus.Subscribe(EntityEvents.ENTITY_CREATED, function(EventData)
	local EntityInstance = EventData.Entity
	if not EntityInstance.IsPlayer then
		return
	end

	EntityUpdateData[EntityInstance] = {
		LastWalkSpeedUpdate = 0,
		MovementTickAccumulator = 0,
	}

	SetupMovementTracking(EntityInstance)

	UpdateService.Register(function(DeltaTime: number)
		if not EntityInstance.Character or not EntityInstance.Character.Parent then
			return
		end

		if EntityInstance.Components.BodyFatigue then
			EntityInstance.Components.BodyFatigue:Update(DeltaTime)
		end

		if EntityInstance.Components.Hunger then
			EntityInstance.Components.Hunger:Update()
		end

		if EntityInstance.Components.Training then
			EntityInstance.Components.Training:ProcessTraining(DeltaTime)
		end

		UpdateStaminaAndMovement(EntityInstance, DeltaTime)
		EnforceWalkSpeed(EntityInstance)
	end, 1 / 10)
end)

EventBus.Subscribe(EntityEvents.ENTITY_DESTROYED, function(EventData)
	local EntityInstance = EventData.Entity
	EntityUpdateData[EntityInstance] = nil
end)

return EntityUpdateSystem
