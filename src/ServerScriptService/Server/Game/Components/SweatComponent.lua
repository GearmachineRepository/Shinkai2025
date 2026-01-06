--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StatTypes = require(Shared.Config.Enums.StatTypes)
local Formulas = require(Shared.Utility.Formulas)
local HungerBalance = require(Shared.Config.Body.HungerBalance)

local SweatComponent = {}
SweatComponent.__index = SweatComponent

SweatComponent.ComponentName = "Sweat"
SweatComponent.Dependencies = { "Stats" }
SweatComponent.UpdateRate = 1 / 2

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	Character: Model,
	IsActive: boolean,
	LastActivityTime: number,
	SweatStartTime: number,
	LastSweatState: boolean,
}

function SweatComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		Character = Entity.Character,
		IsActive = false,
		LastActivityTime = 0,
		SweatStartTime = 0,
		LastSweatState = false,
	}, SweatComponent) :: any

	SweatComponent.SetupActivityTracking(self)

	return self
end

function SweatComponent.SetupActivityTracking(self: Self)
	local AttributesToTrack = { "MovementMode", "Training", "UsingSkill", "Attacking" }

	for _, AttributeName in AttributesToTrack do
		self.Maid:GiveTask(self.Character:GetAttributeChangedSignal(AttributeName):Connect(function()
			SweatComponent.CheckActivity(self)
		end))
	end
end

function SweatComponent.CheckActivity(self: Self)
	local IsSprinting = self.Character:GetAttribute("Sprinting")
	local IsTraining = self.Character:GetAttribute("Training")
	local IsUsingSkill = self.Character:GetAttribute("UsingSkill")
	local IsAttacking = self.Character:GetAttribute("Attacking")

	local IsDoingActivity = IsSprinting or IsTraining or IsUsingSkill or IsAttacking

	if IsDoingActivity then
		self.LastActivityTime = tick()
	end
end

function SweatComponent.Update(self: Self, _DeltaTime: number)
	local CurrentStamina = self.Entity.Stats:GetStat(StatTypes.STAMINA)
	local MaxStamina = self.Entity.Stats:GetStat(StatTypes.MAX_STAMINA)
	local StaminaPercent = Formulas.SafeDivide(CurrentStamina, MaxStamina)

	local TimeSinceActivity = tick() - self.LastActivityTime
	local IsRecentlyActive = TimeSinceActivity < HungerBalance.Sweat.ActivityTimeoutSeconds

	local ShouldStartSweating = StaminaPercent < HungerBalance.Sweat.StaminaThresholdPercent and IsRecentlyActive

	if ShouldStartSweating and not self.IsActive then
		SweatComponent.StartSweating(self)
	elseif self.IsActive then
		local TimeSinceSweatStart = tick() - self.SweatStartTime
		if TimeSinceSweatStart >= HungerBalance.Sweat.CooldownDurationSeconds then
			SweatComponent.StopSweating(self)
		end
	end
end

function SweatComponent.StartSweating(self: Self)
	self.IsActive = true
	self.SweatStartTime = tick()

	if self.LastSweatState ~= true then
		self.Character:SetAttribute("Sweating", true)
		self.LastSweatState = true
	end
end

function SweatComponent.StopSweating(self: Self)
	self.IsActive = false

	if self.LastSweatState ~= false then
		self.Character:SetAttribute("Sweating", false)
		self.LastSweatState = false
	end
end

function SweatComponent.GetStatGainMultiplier(self: Self): number
	return self.IsActive and HungerBalance.Sweat.StatGainMultiplier or 1.0
end

function SweatComponent.GetHungerDrainMultiplier(self: Self): number
	return self.IsActive and HungerBalance.Sweat.HungerDrainMultiplier or 1.0
end

function SweatComponent.Destroy(self: Self)
	SweatComponent.StopSweating(self)
	self.Maid:DoCleaning()
end

return SweatComponent