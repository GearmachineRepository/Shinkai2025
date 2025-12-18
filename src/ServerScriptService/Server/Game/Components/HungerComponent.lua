--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local Maid = require(Shared.General.Maid)

export type HungerComponent = {
	Entity: any,
	Update: (self: HungerComponent, DeltaTime: number) -> (),
	Feed: (self: HungerComponent, Amount: number) -> (),
	GetHungerPercent: (self: HungerComponent) -> number,
	ConsumeHungerForStamina: (self: HungerComponent, StaminaUsed: number) -> (),
	IsStarving: (self: HungerComponent) -> boolean,
	GetStatGainMultiplier: (self: HungerComponent) -> number,
	Destroy: (self: HungerComponent) -> (),
}

type HungerComponentInternal = HungerComponent & {
	Maid: Maid.MaidSelf,
}

local HungerComponent = {}
HungerComponent.__index = HungerComponent

function HungerComponent.new(Entity: any): HungerComponent
	local self: HungerComponentInternal = setmetatable({
		Entity = Entity,
		Maid = Maid.new(),
	}, HungerComponent) :: any

	Entity.Character:SetAttribute("HungerThreshold", TrainingBalance.HungerSystem.STAT_GAIN_THRESHOLD / 100)
	Entity.Character:SetAttribute("MaxFat", TrainingBalance.FatSystem.MAX_FAT)

	return self
end

function HungerComponent:Update(DeltaTime: number)
	local DecayRate = TrainingBalance.HungerSystem.DECAY_RATE

	if self.Entity.Components.Sweat then
		DecayRate = DecayRate * self.Entity.Components.Sweat:GetHungerDrainMultiplier()
	end

	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - (DecayRate * DeltaTime))

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)

	if NewHunger < TrainingBalance.HungerSystem.CRITICAL_THRESHOLD then
		self.Entity.States:FireEvent("HungerCritical", { HungerPercent = self:GetHungerPercent() })
	end
end

function HungerComponent:Feed(Amount: number)
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Entity.Stats:GetStat(StatTypes.MAX_HUNGER)
	local NewHunger = math.min(MaxHunger, CurrentHunger + Amount)

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerComponent:GetHungerPercent(): number
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Entity.Stats:GetStat(StatTypes.MAX_HUNGER)

	if MaxHunger == 0 then
		return 0
	end

	return (CurrentHunger / MaxHunger) * 100
end

function HungerComponent:ConsumeHungerForStamina(StaminaUsed: number)
	local HungerCost = StaminaUsed * TrainingBalance.HungerSystem.STAMINA_TO_HUNGER_RATIO
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerComponent:IsStarving(): boolean
	return self:GetHungerPercent() < TrainingBalance.HungerSystem.CRITICAL_THRESHOLD
end

function HungerComponent:GetStatGainMultiplier(): number
	local HungerPercent = self:GetHungerPercent()

	if HungerPercent >= TrainingBalance.HungerSystem.STAT_GAIN_THRESHOLD then
		return TrainingBalance.HungerSystem.STAT_GAIN_MULTIPLIER_NORMAL
	else
		return TrainingBalance.HungerSystem.STAT_GAIN_MULTIPLIER_STARVING
	end
end

function HungerComponent:Destroy()
	self.Maid:DoCleaning()
end

return HungerComponent
