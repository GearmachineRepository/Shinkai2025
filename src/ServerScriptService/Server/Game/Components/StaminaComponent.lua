--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StatTypes = require(Shared.Config.Enums.StatTypes)
local CharacterBalance = require(Shared.Config.Balance.CharacterBalance)
local Formulas = require(Shared.Utility.Formulas)

local StaminaComponent = {}
StaminaComponent.__index = StaminaComponent

StaminaComponent.ComponentName = "Stamina"
StaminaComponent.Dependencies = { "Stats" }
StaminaComponent.UpdateRate = 1 / 30

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	LastStaminaUse: number,
	IsExhausted: boolean,
	SprintStartTime: number?,
	JogStartTime: number?,
	LastSprintEndTime: number,
	LastJogEndTime: number,
	CachedMaxStamina: number,
}

function StaminaComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		LastStaminaUse = 0,
		IsExhausted = false,
		SprintStartTime = nil,
		JogStartTime = nil,
		LastSprintEndTime = 0,
		LastJogEndTime = 0,
		CachedMaxStamina = 75,
	}, StaminaComponent) :: any

	self.CachedMaxStamina = StaminaComponent.GetMaxStamina(self)

	return self
end

function StaminaComponent.GetStamina(self: Self): number
	return self.Entity.Stats:GetStat(StatTypes.STAMINA)
end

function StaminaComponent.GetMaxStamina(self: Self): number
	local NewMax = self.Entity.Stats:GetStat(StatTypes.MAX_STAMINA)
	if not Formulas.IsNearlyEqual(NewMax, self.CachedMaxStamina, 0.1) then
		self.CachedMaxStamina = NewMax
	end
	return self.CachedMaxStamina
end

function StaminaComponent.HasMinimumStamina(self: Self, MovementMode: string): boolean
	local CurrentStamina = StaminaComponent.GetStamina(self)
	local MinBuffer = CharacterBalance.Sprint.MinStaminaBuffer

	local CostPerSecond = if MovementMode == "run"
		then CharacterBalance.Stamina.SprintCost
		else CharacterBalance.Stamina.JogCost

	return CurrentStamina > (CostPerSecond + MinBuffer)
end

function StaminaComponent.CanSprint(self: Self): boolean
	if self.IsExhausted then
		return false
	end

	return StaminaComponent.HasMinimumStamina(self, "run")
end

function StaminaComponent.CanJog(self: Self): boolean
	if self.IsExhausted then
		return false
	end

	return StaminaComponent.HasMinimumStamina(self, "jog")
end

function StaminaComponent.GetStutterStepMultiplier(self: Self, MovementType: string): number
	local CurrentTime = os.clock()
	local StartTime = if MovementType == "run" then self.SprintStartTime else self.JogStartTime
	local LastEndTime = if MovementType == "run" then self.LastSprintEndTime else self.LastJogEndTime

	if not StartTime then
		return 1
	end

	local TimeSinceStart = CurrentTime - StartTime
	local TimeSinceLastEnd = CurrentTime - LastEndTime

	if TimeSinceStart > CharacterBalance.StutterStep.GracePeriod then
		return 1
	end

	if TimeSinceLastEnd < CharacterBalance.StutterStep.Cooldown then
		return 1
	end

	return 1 - Formulas.FromPercentage(CharacterBalance.StutterStep.ReductionPercent, 1)
end

function StaminaComponent.OnSprintStart(self: Self)
	self.SprintStartTime = os.clock()
end

function StaminaComponent.OnSprintEnd(self: Self)
	self.LastSprintEndTime = os.clock()
	self.SprintStartTime = nil
end

function StaminaComponent.OnJogStart(self: Self)
	self.JogStartTime = os.clock()
end

function StaminaComponent.OnJogEnd(self: Self)
	self.LastJogEndTime = os.clock()
	self.JogStartTime = nil
end

function StaminaComponent.ApplyStamina(self: Self, TargetStamina: number)
	if not self.Entity.Character then
		return
	end

	local MaxStamina = StaminaComponent.GetMaxStamina(self)
	local ClampedStamina = math.clamp(TargetStamina, 0, MaxStamina)

	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	if ClampedStamina ~= CurrentStamina then
		self.Entity.Stats:SetStat(StatTypes.STAMINA, ClampedStamina)
	end

	if ClampedStamina <= 0 and not self.IsExhausted then
		self.IsExhausted = true
		self.Entity.States:SetState("Exhausted", true)
	elseif self.IsExhausted and ClampedStamina >= CharacterBalance.Stamina.ExhaustionThreshold then
		self.IsExhausted = false
		self.Entity.States:SetState("Exhausted", false)
	end
end

function StaminaComponent.ConsumeStamina(self: Self, Amount: number): boolean
	if Amount <= 0 then
		return true
	end

	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local TargetStamina = CurrentStamina - Amount

	if TargetStamina < 0 then
		return false
	end

	self.LastStaminaUse = os.clock()
	StaminaComponent.ApplyStamina(self, TargetStamina)

	return true
end

function StaminaComponent.RestoreStamina(self: Self, Amount: number)
	if Amount <= 0 then
		return
	end

	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	StaminaComponent.ApplyStamina(self, CurrentStamina + Amount)
end

function StaminaComponent.Update(self: Self, DeltaTime: number, MovementMode: string?, IsMoving: boolean): boolean
	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local MaxStamina = StaminaComponent.GetMaxStamina(self)

	local AllowMovement = true
	local TargetStamina = CurrentStamina

	if IsMoving and (MovementMode == "run" or MovementMode == "jog") then
		if self.IsExhausted then
			return false
		end

		local StutterStepMultiplier = StaminaComponent.GetStutterStepMultiplier(self, MovementMode)
		local CostPerSecond = if MovementMode == "run"
			then CharacterBalance.Stamina.SprintCost
			else CharacterBalance.Stamina.JogCost

		local Drain = CostPerSecond * DeltaTime * StutterStepMultiplier
		TargetStamina = TargetStamina - Drain

		if TargetStamina <= 0 then
			TargetStamina = 0
			AllowMovement = false
		end

		self.LastStaminaUse = os.clock()
	end

	local TimeSinceUse = os.clock() - self.LastStaminaUse
	if TimeSinceUse >= CharacterBalance.Stamina.RegenDelay then
		local Regen = CharacterBalance.Stamina.RegenRate * DeltaTime
		TargetStamina = math.min(TargetStamina + Regen, MaxStamina)

		local Hunger = self.Entity:GetComponent("Hunger") :: any
		if Hunger then
			Hunger:ConsumeHungerForStamina(Regen)
		end
	end

	StaminaComponent.ApplyStamina(self, TargetStamina)

	return AllowMovement
end

function StaminaComponent.SetStamina(self: Self, TargetStamina: number)
	if not self.Entity.Character then
		return
	end

	StaminaComponent.ApplyStamina(self, TargetStamina)
end

function StaminaComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return StaminaComponent
