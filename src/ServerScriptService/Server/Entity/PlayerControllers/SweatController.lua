--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Maid = require(Shared.General.Maid)

local SweatController = {}
SweatController.__index = SweatController

export type SweatController = typeof(setmetatable({} :: {
	Controller: any,
	Character: Model,
	IsActive: boolean,
	LastActivityTime: number,
	SweatStartTime: number,
	Maid: Maid.MaidSelf,
}, SweatController))

local SWEAT_STAMINA_THRESHOLD = 0.75
local ACTIVITY_TIMEOUT = 5
local SWEAT_COOLDOWN_DURATION = 120
local STAT_GAIN_MULTIPLIER = 1.15
local HUNGER_DRAIN_MULTIPLIER = 1.25

function SweatController.new(CharacterController: any): SweatController
	local self = setmetatable({
		Controller = CharacterController,
		Character = CharacterController.Character,
		IsActive = false,
		LastActivityTime = 0,
		SweatStartTime = 0,
		Maid = Maid.new(),
	}, SweatController)

	self:SetupActivityTracking()

	self.Maid:GiveTask(RunService.Heartbeat:Connect(function()
		self:Update()
	end))

	return self
end

function SweatController:SetupActivityTracking()
	self.Maid:GiveTask(self.Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		self:CheckActivity()
	end))

	self.Maid:GiveTask(self.Character:GetAttributeChangedSignal("Training"):Connect(function()
		self:CheckActivity()
	end))

	self.Maid:GiveTask(self.Character:GetAttributeChangedSignal("UsingSkill"):Connect(function()
		self:CheckActivity()
	end))

	self.Maid:GiveTask(self.Character:GetAttributeChangedSignal("Attacking"):Connect(function()
		self:CheckActivity()
	end))
end

function SweatController:CheckActivity()
	local MovementMode = self.Character:GetAttribute("MovementMode")
	local IsTraining = self.Character:GetAttribute("Training")
	local IsUsingSkill = self.Character:GetAttribute("UsingSkill")
	local IsAttacking = self.Character:GetAttribute("Attacking")

	local IsDoingActivity = MovementMode == "jog"
		or MovementMode == "run"
		or IsTraining
		or IsUsingSkill
		or IsAttacking

	if IsDoingActivity then
		self.LastActivityTime = tick()
	end
end

function SweatController:Update()
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local MaxStamina = self.Controller.StatManager:GetStat(StatTypes.MAX_STAMINA)
	local StaminaPercent = CurrentStamina / MaxStamina

	local TimeSinceActivity = tick() - self.LastActivityTime
	local IsRecentlyActive = TimeSinceActivity < ACTIVITY_TIMEOUT

	local ShouldStartSweating = StaminaPercent < SWEAT_STAMINA_THRESHOLD and IsRecentlyActive

	if ShouldStartSweating and not self.IsActive then
		self:StartSweating()
	elseif self.IsActive then
		local TimeSinceSweatStart = tick() - self.SweatStartTime
		if TimeSinceSweatStart >= SWEAT_COOLDOWN_DURATION then
			self:StopSweating()
		end
	end
end

function SweatController:StartSweating()
	self.IsActive = true
	self.SweatStartTime = tick()
	self.Character:SetAttribute("Sweating", true)
end

function SweatController:StopSweating()
	self.IsActive = false
	self.Character:SetAttribute("Sweating", false)
end

function SweatController:GetStatGainMultiplier(): number
	return self.IsActive and STAT_GAIN_MULTIPLIER or 1.0
end

function SweatController:GetHungerDrainMultiplier(): number
	return self.IsActive and HUNGER_DRAIN_MULTIPLIER or 1.0
end

function SweatController:Destroy()
	self:StopSweating()
	self.Maid:DoCleaning()
end

return SweatController