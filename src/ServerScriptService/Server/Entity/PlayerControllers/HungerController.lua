--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local Maid = require(Shared.General.Maid)

local HungerController = {}
HungerController.__index = HungerController

export type HungerController = typeof(setmetatable(
	{} :: {
		Controller: any,
		LastUpdate: number,
		Maid: Maid.MaidSelf,
	},
	HungerController
))

function HungerController.new(CharacterController: any): HungerController
	local self = setmetatable({
		Controller = CharacterController,
		LastUpdate = tick(),
		Maid = Maid.new(),
	}, HungerController)

	CharacterController.Character:SetAttribute(
		"HungerThreshold",
		TrainingBalance.HungerSystem.STAT_GAIN_THRESHOLD / 100
	)
	CharacterController.Character:SetAttribute("MaxFat", TrainingBalance.FatSystem.MAX_FAT)

	return self
end

function HungerController:Update()
	local Now = tick()
	local DeltaTime = Now - self.LastUpdate
	self.LastUpdate = Now

	if DeltaTime > 5 then
		return
	end

	local DecayRate = TrainingBalance.HungerSystem.DECAY_RATE

	if self.Controller.SweatController then
		DecayRate = DecayRate * self.Controller.SweatController:GetHungerDrainMultiplier()
	end

	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - (DecayRate * DeltaTime))

	self.Controller.StatManager:SetStat(StatTypes.HUNGER, NewHunger)

	if NewHunger < TrainingBalance.HungerSystem.CRITICAL_THRESHOLD then
		self.Controller.StateManager:FireEvent("HungerCritical", { HungerPercent = self:GetHungerPercent() })
	end
end

function HungerController:Feed(Amount: number)
	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Controller.StatManager:GetStat(StatTypes.MAX_HUNGER)
	local NewHunger = math.min(MaxHunger, CurrentHunger + Amount)

	self.Controller.StatManager:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerController:GetHungerPercent(): number
	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Controller.StatManager:GetStat(StatTypes.MAX_HUNGER)

	if MaxHunger == 0 then
		return 0
	end

	return (CurrentHunger / MaxHunger) * 100
end

function HungerController:ConsumeHungerForStamina(StaminaUsed: number)
	local HungerCost = StaminaUsed * TrainingBalance.HungerSystem.STAMINA_TO_HUNGER_RATIO
	local CurrentHunger = self.Controller.StatManager:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	self.Controller.StatManager:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerController:IsStarving(): boolean
	return self:GetHungerPercent() < TrainingBalance.HungerSystem.CRITICAL_THRESHOLD
end

function HungerController:GetStatGainMultiplier(): number
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent >= TrainingBalance.HungerSystem.STAT_GAIN_THRESHOLD then
		return TrainingBalance.HungerSystem.STAT_GAIN_MULTIPLIER_NORMAL
	else
		return TrainingBalance.HungerSystem.STAT_GAIN_MULTIPLIER_STARVING
	end
end

function HungerController:Destroy()
	self.Maid:DoCleaning()
end

return HungerController
