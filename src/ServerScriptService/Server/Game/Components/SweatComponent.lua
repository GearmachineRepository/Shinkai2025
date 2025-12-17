--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Formulas = require(Shared.General.Formulas)
local Maid = require(Shared.General.Maid)
local SweatBalance = require(Shared.Configurations.Balance.SweatBalance)

export type SweatComponent = {
	Entity: any,
	Update: (self: SweatComponent) -> (),
	GetStatGainMultiplier: (self: SweatComponent) -> number,
	GetHungerDrainMultiplier: (self: SweatComponent) -> number,
	Destroy: (self: SweatComponent) -> (),
}

type SweatComponentInternal = SweatComponent & {
	Character: Model,
	IsActive: boolean,
	LastActivityTime: number,
	SweatStartTime: number,
	LastSweatState: boolean,
	Maid: Maid.MaidSelf,
}

local SweatComponent = {}
SweatComponent.__index = SweatComponent

function SweatComponent.new(Entity: any): SweatComponent
	local self: SweatComponentInternal = setmetatable({
		Entity = Entity,
		Character = Entity.Character,
		IsActive = false,
		LastActivityTime = 0,
		SweatStartTime = 0,
		Maid = Maid.new(),
		LastSweatState = false,
	}, SweatComponent) :: any

	self:SetupActivityTracking()

	return self
end

function SweatComponent:SetupActivityTracking()
	local AttributesToTrack = { "MovementMode", "Training", "UsingSkill", "Attacking" }

	for _, AttributeName in AttributesToTrack do
		self.Maid:GiveTask(self.Character:GetAttributeChangedSignal(AttributeName):Connect(function()
			self:CheckActivity()
		end))
	end
end

function SweatComponent:CheckActivity()
	local MovementMode = self.Character:GetAttribute("MovementMode")
	local IsTraining = self.Character:GetAttribute("Training")
	local IsUsingSkill = self.Character:GetAttribute("UsingSkill")
	local IsAttacking = self.Character:GetAttribute("Attacking")

	local IsDoingActivity = MovementMode == "jog" or MovementMode == "run" or IsTraining or IsUsingSkill or IsAttacking

	if IsDoingActivity then
		self.LastActivityTime = tick()
	end
end

function SweatComponent:Update()
	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local MaxStamina = self.Entity.Stats:GetStat(StatTypes.MAX_STAMINA)
	local StaminaPercent = Formulas.SafeDivide(CurrentStamina, MaxStamina)

	local TimeSinceActivity = tick() - self.LastActivityTime
	local IsRecentlyActive = TimeSinceActivity < SweatBalance.Thresholds.ACTIVITY_TIMEOUT_SECONDS

	local ShouldStartSweating = StaminaPercent < SweatBalance.Thresholds.STAMINA_THRESHOLD_PERCENT and IsRecentlyActive

	if ShouldStartSweating and not self.IsActive then
		self:StartSweating()
	elseif self.IsActive then
		local TimeSinceSweatStart = tick() - self.SweatStartTime
		if TimeSinceSweatStart >= SweatBalance.Cooldown.DURATION_SECONDS then
			self:StopSweating()
		end
	end
end

function SweatComponent:StartSweating()
	self.IsActive = true
	self.SweatStartTime = tick()

	if self.LastSweatState ~= true then
		self.Character:SetAttribute("Sweating", true)
		self.LastSweatState = true
	end
end

function SweatComponent:StopSweating()
	self.IsActive = false

	if self.LastSweatState ~= false then
		self.Character:SetAttribute("Sweating", false)
		self.LastSweatState = false
	end
end

function SweatComponent:GetStatGainMultiplier(): number
	return self.IsActive and SweatBalance.Multipliers.STAT_GAIN or 1.0
end

function SweatComponent:GetHungerDrainMultiplier(): number
	return self.IsActive and SweatBalance.Multipliers.HUNGER_DRAIN or 1.0
end

function SweatComponent:Destroy()
	self:StopSweating()
	self.Maid:DoCleaning()
end

return SweatComponent
