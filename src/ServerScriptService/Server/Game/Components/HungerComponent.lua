--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)

local HungerComponent = {}
HungerComponent.__index = HungerComponent

HungerComponent.ComponentName = "Hunger"
HungerComponent.Dependencies = { "Stats" }
HungerComponent.UpdateRate = 1

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
}

function HungerComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
	}, HungerComponent) :: any

	Entity.Character:SetAttribute("HungerThreshold", TrainingBalance.HungerSystem.STAT_GAIN_THRESHOLD / 100)
	Entity.Character:SetAttribute("MaxFat", TrainingBalance.FatSystem.MAX_FAT)

	return self
end

function HungerComponent.Update(self: Self, DeltaTime: number)
	local DecayRate = TrainingBalance.HungerSystem.DECAY_RATE

	local Sweat = self.Entity:GetComponent("Sweat") :: any
	if Sweat then
		DecayRate = DecayRate * Sweat:GetHungerDrainMultiplier()
	end

	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - (DecayRate * DeltaTime))

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)

	if NewHunger < TrainingBalance.HungerSystem.CRITICAL_THRESHOLD then
		Ensemble.Events.Publish("HungerCritical", {
			Entity = self.Entity,
			HungerPercent = HungerComponent.GetHungerPercent(self),
		})
	end
end

function HungerComponent.Feed(self: Self, Amount: number)
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Entity.Stats:GetStat(StatTypes.MAX_HUNGER)
	local NewHunger = math.min(MaxHunger, CurrentHunger + Amount)

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerComponent.GetHungerPercent(self: Self): number
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local MaxHunger = self.Entity.Stats:GetStat(StatTypes.MAX_HUNGER)

	if MaxHunger == 0 then
		return 0
	end

	return (CurrentHunger / MaxHunger) * 100
end

function HungerComponent.ConsumeHungerForStamina(self: Self, StaminaUsed: number)
	local HungerCost = StaminaUsed * TrainingBalance.HungerSystem.STAMINA_TO_HUNGER_RATIO
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerComponent.IsStarving(self: Self): boolean
	return HungerComponent.GetHungerPercent(self) < TrainingBalance.HungerSystem.CRITICAL_THRESHOLD
end

function HungerComponent.GetStatGainMultiplier(self: Self): number
	local HungerPercent = HungerComponent.GetHungerPercent(self)

	if HungerPercent >= TrainingBalance.HungerSystem.STAT_GAIN_THRESHOLD then
		return TrainingBalance.HungerSystem.STAT_GAIN_MULTIPLIER_NORMAL
	else
		return TrainingBalance.HungerSystem.STAT_GAIN_MULTIPLIER_STARVING
	end
end

function HungerComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return HungerComponent