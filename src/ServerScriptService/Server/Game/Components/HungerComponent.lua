--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StatTypes = require(Shared.Config.Enums.StatTypes)
local HungerBalance = require(Shared.Config.Body.HungerBalance)
local BodyBalance = require(Shared.Config.Body.BodyBalance)

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

	Entity.Character:SetAttribute("HungerThreshold", HungerBalance.Hunger.StatGainThreshold / 100)
	Entity.Character:SetAttribute("MaxFat", BodyBalance.Fat.MaxFat)

	return self
end

function HungerComponent.Update(self: Self, DeltaTime: number)
	local DecayRate = HungerBalance.Hunger.DecayRate

	local Sweat = self.Entity:GetComponent("Sweat") :: any
	if Sweat then
		DecayRate = DecayRate * Sweat:GetHungerDrainMultiplier()
	end

	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - (DecayRate * DeltaTime))

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)

	if NewHunger < HungerBalance.Hunger.CriticalThreshold then
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
	local HungerCost = StaminaUsed * HungerBalance.Hunger.StaminaToHungerRatio
	local CurrentHunger = self.Entity.Stats:GetStat(StatTypes.HUNGER)
	local NewHunger = math.max(0, CurrentHunger - HungerCost)

	self.Entity.Stats:SetStat(StatTypes.HUNGER, NewHunger)
end

function HungerComponent.IsStarving(self: Self): boolean
	return HungerComponent.GetHungerPercent(self) < HungerBalance.Hunger.CriticalThreshold
end

function HungerComponent.GetStatGainMultiplier(self: Self): number
	local HungerPercent = HungerComponent.GetHungerPercent(self)

	if HungerPercent >= HungerBalance.Hunger.StatGainThreshold then
		return HungerBalance.Hunger.StatGainMultiplierNormal
	else
		return HungerBalance.Hunger.StatGainMultiplierStarving
	end
end

function HungerComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return HungerComponent