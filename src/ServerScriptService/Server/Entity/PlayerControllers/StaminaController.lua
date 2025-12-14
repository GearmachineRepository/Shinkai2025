--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StaminaBalance = require(Shared.Configurations.Balance.StaminaBalance)
local Formulas = require(Shared.General.Formulas)
local Maid = require(Shared.General.Maid)
local DebugLogger = require(Shared.Debug.DebugLogger)

local StaminaController = {}
StaminaController.__index = StaminaController

export type StaminaController = typeof(setmetatable(
	{} :: {
		Controller: any,
		LastStaminaUse: number,
		IsExhausted: boolean,
		SprintStartTime: number?,
		JogStartTime: number?,
		LastSprintEndTime: number,
		LastJogEndTime: number,
		Maid: Maid.MaidSelf,
		CachedMaxStamina: number,
		LastStaminaValue: number,

		SyncAccumulator: number,
		PendingDelta: number,
	},
	StaminaController
))

local STAMINA_UPDATE_THRESHOLD = 0.01
local STAMINA_SYNC_RATE_SECONDS = 0.10
local STAMINA_QUANTUM = 0.10

local function QuantizeStamina(Value: number): number
	return math.floor((Value / STAMINA_QUANTUM) + 0.5) * STAMINA_QUANTUM
end

function StaminaController.new(CharacterController: any): StaminaController
	local self = setmetatable({
		Controller = CharacterController,
		LastStaminaUse = 0,
		IsExhausted = false,
		SprintStartTime = nil,
		JogStartTime = nil,
		LastSprintEndTime = 0,
		LastJogEndTime = 0,
		Maid = Maid.new(),
		CachedMaxStamina = 75,
		LastStaminaValue = 75,

		SyncAccumulator = 0,
		PendingDelta = 0,
	}, StaminaController)

	self.CachedMaxStamina = self:GetMaxStamina()
	self.LastStaminaValue = self.Controller.StatManager:GetStat(StatTypes.STAMINA)

	return self
end

function StaminaController:GetMaxStamina(): number
	local NewMax = self.Controller.StatManager:GetStat(StatTypes.MAX_STAMINA)
	if not Formulas.IsNearlyEqual(NewMax, self.CachedMaxStamina, 0.1) then
		self.CachedMaxStamina = NewMax
	end
	return self.CachedMaxStamina
end

function StaminaController:CanSprint(): boolean
	return not self.IsExhausted
end

function StaminaController:CanJog(): boolean
	return not self.IsExhausted
end

function StaminaController:GetStutterStepMultiplier(MovementType: string): number
	local CurrentTime = os.clock()
	local StartTime = if MovementType == "run" then self.SprintStartTime else self.JogStartTime
	local LastEndTime = if MovementType == "run" then self.LastSprintEndTime else self.LastJogEndTime

	if not StartTime then
		return 1
	end

	local TimeSinceStart = CurrentTime - StartTime
	local TimeSinceLastEnd = CurrentTime - LastEndTime

	if TimeSinceStart > StaminaBalance.StutterStep.GRACE_PERIOD then
		return 1
	end

	if TimeSinceLastEnd < StaminaBalance.StutterStep.COOLDOWN then
		return 1
	end

	return 1 - Formulas.FromPercentage(StaminaBalance.StutterStep.REDUCTION_PERCENT, 1)
end

function StaminaController:OnSprintStart()
	self.SprintStartTime = os.clock()
end

function StaminaController:OnSprintEnd()
	self.LastSprintEndTime = os.clock()
	self.SprintStartTime = nil
end

function StaminaController:OnJogStart()
	self.JogStartTime = os.clock()
end

function StaminaController:OnJogEnd()
	self.LastJogEndTime = os.clock()
	self.JogStartTime = nil
end

function StaminaController:ConsumeStamina(Amount: number): boolean
	if Amount <= 0 then
		return true
	end

	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local TargetStamina = CurrentStamina + self.PendingDelta - Amount

	if TargetStamina <= 0 then
		self.PendingDelta = -CurrentStamina
		self.LastStaminaUse = os.clock()
		self.SyncAccumulator = 0
		self:ApplyStamina(0, true)
		return false
	end

	self.PendingDelta -= Amount
	self.LastStaminaUse = os.clock()
	self.SyncAccumulator = 0
	self:ApplyStamina(CurrentStamina + self.PendingDelta, true)

	return true
end

function StaminaController:RestoreStaminaExternal(Amount: number)
	if Amount <= 0 then
		return
	end

	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	self.PendingDelta += Amount
	self.SyncAccumulator = 0
	self:ApplyStamina(CurrentStamina + self.PendingDelta, true)
end

function StaminaController:ApplyStamina(TargetStamina: number, ForceSync: boolean)
	if not self.Controller.Character then
		return
	end

	local MaxStamina = self:GetMaxStamina()
	local Clamped = math.clamp(TargetStamina, 0, MaxStamina)

	local Quantized = QuantizeStamina(Clamped)

	if (MaxStamina - Clamped) <= (STAMINA_QUANTUM * 0.5) then
		Quantized = MaxStamina
	end

	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local DeltaApplied = Quantized - CurrentStamina
	self.PendingDelta -= DeltaApplied

	if ForceSync or not Formulas.IsNearlyEqual(Quantized, self.LastStaminaValue, STAMINA_UPDATE_THRESHOLD) then
		self.Controller.StatManager:SetStat(StatTypes.STAMINA, Quantized)
		self.LastStaminaValue = Quantized
	end

	if Quantized <= 0 and not self.IsExhausted then
		self.IsExhausted = true
		self.Controller.StateManager:SetState("Exhausted", true)
		DebugLogger.Info("StaminaController", "Player exhausted: %s", self.Controller.Character.Name)
	elseif self.IsExhausted and Quantized >= StaminaBalance.Exhaustion.THRESHOLD then
		self.IsExhausted = false
		self.Controller.StateManager:SetState("Exhausted", false)
		DebugLogger.Info("StaminaController", "Player recovered: %s", self.Controller.Character.Name)
	end
end

function StaminaController:Update(DeltaTime: number, MovementMode: string?, IsMoving: boolean): boolean
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local MaxStamina = self:GetMaxStamina()

	local DrainMultiplier = 1
	if self.Controller.BodyFatigueController then
		DrainMultiplier = self.Controller.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local ForceSync = false
	local AllowMovement = true

	if IsMoving and (MovementMode == "run" or MovementMode == "jog") then
		if (MovementMode == "run" and not self:CanSprint()) or (MovementMode == "jog" and not self:CanJog()) then
			return false
		end

		local StutterStepMultiplier = self:GetStutterStepMultiplier(MovementMode)
		local CostPerSecond = if MovementMode == "run"
			then StaminaBalance.StaminaCosts.SPRINT
			else StaminaBalance.StaminaCosts.JOG
		local Drain = CostPerSecond * DeltaTime * DrainMultiplier * StutterStepMultiplier

		local Predicted = CurrentStamina + self.PendingDelta - Drain
		if Predicted <= 0 then
			self.PendingDelta = -CurrentStamina
			self.LastStaminaUse = os.clock()
			ForceSync = true
			AllowMovement = false
		else
			self.PendingDelta -= Drain
			self.LastStaminaUse = os.clock()
		end
	end

	local TimeSinceUse = os.clock() - self.LastStaminaUse
	if TimeSinceUse >= StaminaBalance.Regeneration.DELAY then
		local Regen = StaminaBalance.Regeneration.RATE * DeltaTime
		local Predicted = CurrentStamina + self.PendingDelta + Regen

		if Predicted >= MaxStamina then
			self.PendingDelta = MaxStamina - CurrentStamina
			ForceSync = true
		else
			self.PendingDelta += Regen

			if self.Controller.HungerController then
				self.Controller.HungerController:ConsumeHungerForStamina(Regen)
			end
		end
	end

	self.SyncAccumulator += DeltaTime
	if ForceSync or self.SyncAccumulator >= STAMINA_SYNC_RATE_SECONDS then
		self.SyncAccumulator = 0
		local TargetStamina = CurrentStamina + self.PendingDelta
		self:ApplyStamina(TargetStamina, ForceSync)
	end

	return AllowMovement
end

function StaminaController:Destroy()
	DebugLogger.Info("StaminaController", "Destroying StaminaController for: %s", self.Controller.Character.Name)
	self.Maid:DoCleaning()
end

return StaminaController
