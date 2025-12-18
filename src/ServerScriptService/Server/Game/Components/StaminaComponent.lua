--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StaminaBalance = require(Shared.Configurations.Balance.StaminaBalance)
local Formulas = require(Shared.General.Formulas)
local Maid = require(Shared.General.Maid)

export type StaminaComponent = {
	Entity: any,
	CanSprint: (self: StaminaComponent) -> boolean,
	CanJog: (self: StaminaComponent) -> boolean,
	ConsumeStamina: (self: StaminaComponent, Amount: number) -> boolean,
	RestoreStaminaExternal: (self: StaminaComponent, Amount: number) -> (),
	Update: (self: StaminaComponent, DeltaTime: number, MovementMode: string?, IsMoving: boolean) -> boolean,
	OnSprintStart: (self: StaminaComponent) -> (),
	OnSprintEnd: (self: StaminaComponent) -> (),
	OnJogStart: (self: StaminaComponent) -> (),
	OnJogEnd: (self: StaminaComponent) -> (),
	GetStutterStepMultiplier: (self: StaminaComponent, MovementType: string) -> number,
	Destroy: (self: StaminaComponent) -> (),
}

type StaminaComponentInternal = StaminaComponent & {
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
}

local StaminaComponent = {}
StaminaComponent.__index = StaminaComponent

local function QuantizeStamina(Value: number): number
	return math.floor((Value / StaminaBalance.Sync.QUANTUM) + 0.5) * StaminaBalance.Sync.QUANTUM
end

function StaminaComponent.new(Entity: any): StaminaComponent
	local self: StaminaComponentInternal = setmetatable({
		Entity = Entity,
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
	}, StaminaComponent) :: any

	self.CachedMaxStamina = self:GetMaxStamina()
	self.LastStaminaValue = self.Entity.Stats:GetStat(StatTypes.STAMINA)

	return self
end

function StaminaComponent:GetMaxStamina(): number
	local NewMax = self.Entity.Stats:GetStat(StatTypes.MAX_STAMINA)
	if not Formulas.IsNearlyEqual(NewMax, self.CachedMaxStamina, 0.1) then
		self.CachedMaxStamina = NewMax
	end
	return self.CachedMaxStamina
end

function StaminaComponent:CanSprint(): boolean
	return not self.IsExhausted
end

function StaminaComponent:CanJog(): boolean
	return not self.IsExhausted
end

function StaminaComponent:GetStutterStepMultiplier(MovementType: string): number
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

function StaminaComponent:OnSprintStart()
	self.SprintStartTime = os.clock()
end

function StaminaComponent:OnSprintEnd()
	self.LastSprintEndTime = os.clock()
	self.SprintStartTime = nil
end

function StaminaComponent:OnJogStart()
	self.JogStartTime = os.clock()
end

function StaminaComponent:OnJogEnd()
	self.LastJogEndTime = os.clock()
	self.JogStartTime = nil
end

function StaminaComponent:ConsumeStamina(Amount: number): boolean
	if Amount <= 0 then
		return true
	end

	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local TargetStamina = CurrentStamina + self.PendingDelta - Amount

	if TargetStamina < 0 then
		return false
	end

	self.PendingDelta -= Amount
	self.LastStaminaUse = os.clock()
	self.SyncAccumulator = 0
	self:ApplyStamina(CurrentStamina + self.PendingDelta, true)

	return true
end

function StaminaComponent:RestoreStaminaExternal(Amount: number)
	if Amount <= 0 then
		return
	end

	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	self.PendingDelta += Amount
	self.SyncAccumulator = 0
	self:ApplyStamina(CurrentStamina + self.PendingDelta, true)
end

function StaminaComponent:ApplyStamina(TargetStamina: number, ForceSync: boolean)
	if not self.Entity.Character then
		return
	end

	local MaxStamina = self:GetMaxStamina()
	local Clamped = math.clamp(TargetStamina, 0, MaxStamina)
	local Quantized = QuantizeStamina(Clamped)

	if (MaxStamina - Clamped) <= (StaminaBalance.Sync.QUANTUM * 0.5) then
		Quantized = MaxStamina
	end

	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local DeltaApplied = Quantized - CurrentStamina
	self.PendingDelta -= DeltaApplied

	if
		ForceSync or not Formulas.IsNearlyEqual(Quantized, self.LastStaminaValue, StaminaBalance.Sync.UPDATE_THRESHOLD)
	then
		self.Entity.Stats:SetStat(StatTypes.STAMINA, Quantized)
		self.LastStaminaValue = Quantized
	end

	if Quantized <= 0 and not self.IsExhausted then
		self.IsExhausted = true
		self.Entity.States:SetState("Exhausted", true)
	elseif self.IsExhausted and Quantized >= StaminaBalance.Exhaustion.THRESHOLD then
		self.IsExhausted = false
		self.Entity.States:SetState("Exhausted", false)
	end
end

function StaminaComponent:Update(DeltaTime: number, MovementMode: string?, IsMoving: boolean): boolean
	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local MaxStamina = self:GetMaxStamina()

	local DrainMultiplier = 1
	if self.Entity.Components.BodyFatigue then
		DrainMultiplier = 1.0
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

			if self.Entity.Components.Hunger then
				self.Entity.Components.Hunger:ConsumeHungerForStamina(Regen)
			end
		end
	end

	self.SyncAccumulator += DeltaTime
	if ForceSync or self.SyncAccumulator >= StaminaBalance.Sync.SYNC_RATE_SECONDS then
		self.SyncAccumulator = 0
		local TargetStamina = CurrentStamina + self.PendingDelta
		self:ApplyStamina(TargetStamina, ForceSync)
	end

	return AllowMovement
end

function StaminaComponent:Destroy()
	self.Maid:DoCleaning()
end

return StaminaComponent
