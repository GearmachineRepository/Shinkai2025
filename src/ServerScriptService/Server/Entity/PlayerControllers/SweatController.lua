--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Formulas = require(Shared.General.Formulas)
local Maid = require(Shared.General.Maid)
local DebugLogger = require(Shared.Debug.DebugLogger)

local SweatController = {}
SweatController.__index = SweatController

export type SweatController = typeof(setmetatable(
	{} :: {
		Controller: any,
		Character: Model,
		IsActive: boolean,
		LastActivityTime: number,
		SweatStartTime: number,
		Maid: Maid.MaidSelf,
		LastSweatState: boolean,
	},
	SweatController
))

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
		LastSweatState = false,
	}, SweatController)

	self:SetupActivityTracking()

	return self
end

function SweatController:SetupActivityTracking()
	local AttributesToTrack = {
		"MovementMode",
		"Training",
		"UsingSkill",
		"Attacking",
	}

	for _, AttributeName in AttributesToTrack do
		self.Maid:GiveTask(self.Character:GetAttributeChangedSignal(AttributeName):Connect(function()
			self:CheckActivity()
		end))
	end
end

function SweatController:CheckActivity()
	local MovementMode = self.Character:GetAttribute("MovementMode")
	local IsTraining = self.Character:GetAttribute("Training")
	local IsUsingSkill = self.Character:GetAttribute("UsingSkill")
	local IsAttacking = self.Character:GetAttribute("Attacking")

	local IsDoingActivity = MovementMode == "jog" or MovementMode == "run" or IsTraining or IsUsingSkill or IsAttacking

	if IsDoingActivity then
		self.LastActivityTime = tick()
	end
end

function SweatController:Update()
	local CurrentStamina = self.Controller.StatManager:GetStat(StatTypes.STAMINA)
	local MaxStamina = self.Controller.StatManager:GetStat(StatTypes.MAX_STAMINA)
	local StaminaPercent = Formulas.SafeDivide(CurrentStamina, MaxStamina)

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

	if self.LastSweatState ~= true then
		self.Character:SetAttribute("Sweating", true)
		self.LastSweatState = true

		DebugLogger.Info("SweatController", "Started sweating: %s", self.Controller.Character.Name)
	end
end

function SweatController:StopSweating()
	self.IsActive = false

	if self.LastSweatState ~= false then
		self.Character:SetAttribute("Sweating", false)
		self.LastSweatState = false

		DebugLogger.Info("SweatController", "Stopped sweating: %s", self.Controller.Character.Name)
	end
end

function SweatController:GetStatGainMultiplier(): number
	return self.IsActive and STAT_GAIN_MULTIPLIER or 1.0
end

function SweatController:GetHungerDrainMultiplier(): number
	return self.IsActive and HUNGER_DRAIN_MULTIPLIER or 1.0
end

function SweatController:Destroy()
	self:StopSweating()
	DebugLogger.Info("SweatController", "Destroying SweatController")
	self.Maid:DoCleaning()
end

return SweatController
