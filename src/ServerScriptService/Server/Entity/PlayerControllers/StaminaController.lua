--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StaminaBalance = require(Shared.Configurations.Balance.StaminaBalance)
local Maid = require(Shared.General.Maid)

local StaminaController = {}
StaminaController.__index = StaminaController

export type StaminaController = typeof(setmetatable({} :: {
	Controller: any,
	LastStaminaUse: number,
	IsExhausted: boolean,
	SprintStartTime: number?,
	JogStartTime: number?,
	LastSprintEndTime: number,
	LastJogEndTime: number,
	Maid: Maid.MaidSelf,
}, StaminaController))

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
	}, StaminaController)

	self:StartRegen()

	return self
end

function StaminaController:GetMaxStamina(): number
	return self.Controller.StatManager:GetStat(StatTypes.MAX_STAMINA)
end

function StaminaController:StartRegen()
	self.Maid:Set("StaminaRegen", RunService.Heartbeat:Connect(function(DeltaTime)
		if tick() - self.LastStaminaUse < StaminaBalance.Regeneration.DELAY then
			return
		end

		local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
		local MaxStamina = self:GetMaxStamina()

		if CurrentStamina >= MaxStamina then
			return
		end

		local StaminaGain = StaminaBalance.Regeneration.RATE * DeltaTime
		self:RestoreStamina(StaminaGain)

		if self.Controller.HungerController then
			self.Controller.HungerController:ConsumeHungerForStamina(StaminaGain)
		end
	end))
end

function StaminaController:ConsumeStamina(Amount: number): boolean
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)

	if CurrentStamina >= Amount then
		local NewStamina = CurrentStamina - Amount
		self.Controller.StatManager:SetStat(StatTypes.STAMINA, NewStamina)

		self.LastStaminaUse = tick()

		if NewStamina <= 0 then
			self.IsExhausted = true
			self.Controller.Character:SetAttribute("Exhausted", true)
		end

		return true
	end

	return false
end

function StaminaController:CanSprint(): boolean
	return not self.IsExhausted
end

function StaminaController:CanJog(): boolean
	return not self.IsExhausted
end

function StaminaController:GetStutterStepMultiplier(MovementType: string): number
	local CurrentTime = tick()
	local StartTime = if MovementType == "sprint" then self.SprintStartTime else self.JogStartTime
	local LastEndTime = if MovementType == "sprint" then self.LastSprintEndTime else self.LastJogEndTime

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

	return 1 - (StaminaBalance.StutterStep.REDUCTION_PERCENT / 100)
end

function StaminaController:OnSprintStart()
	self.SprintStartTime = tick()
end

function StaminaController:OnSprintEnd()
	self.LastSprintEndTime = tick()
	self.SprintStartTime = nil
end

function StaminaController:OnJogStart()
	self.JogStartTime = tick()
end

function StaminaController:OnJogEnd()
	self.LastJogEndTime = tick()
	self.JogStartTime = nil
end

function StaminaController:HandleSprint(DeltaTime: number): boolean
	if not self:CanSprint() then
		return false
	end

	local DrainMultiplier = 1
	if self.Controller.BodyFatigueController then
		DrainMultiplier = self.Controller.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local StutterStepMultiplier = self:GetStutterStepMultiplier("sprint")
	local StaminaCost = StaminaBalance.StaminaCosts.SPRINT * DeltaTime * DrainMultiplier * StutterStepMultiplier

	return self:ConsumeStamina(StaminaCost)
end

function StaminaController:HandleJog(DeltaTime: number): boolean
	if not self:CanJog() then
		return false
	end

	local DrainMultiplier = 1
	if self.Controller.BodyFatigueController then
		DrainMultiplier = self.Controller.BodyFatigueController:GetStaminaDrainMultiplier()
	end

	local StutterStepMultiplier = self:GetStutterStepMultiplier("jog")
	local StaminaCost = StaminaBalance.StaminaCosts.JOG * DeltaTime * DrainMultiplier * StutterStepMultiplier

	return self:ConsumeStamina(StaminaCost)
end

function StaminaController:RestoreStamina(Amount: number)
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local MaxStamina = self:GetMaxStamina()
	local NewStamina = math.min(MaxStamina, CurrentStamina + Amount)

	self.Controller.StatManager:SetStat(StatTypes.STAMINA, NewStamina)

	if self.IsExhausted and NewStamina >= StaminaBalance.Exhaustion.THRESHOLD then
		self.IsExhausted = false
		self.Controller.Character:SetAttribute("Exhausted", false)
	end
end

function StaminaController:Destroy()
	self.Maid:DoCleaning()
end

return StaminaController