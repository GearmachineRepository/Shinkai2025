--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local CharacterBalance = require(Shared.Config.Balance.CharacterBalance)
local HungerBalance = require(Shared.Config.Body.HungerBalance)
local FatigueBalance = require(Shared.Config.Body.FatigueBalance)
local TrainingTypesBalance = require(Shared.Config.Body.TrainingTypesBalance)

local CharacterFormulas = {}

function CharacterFormulas.GetStaminaCost(MovementMode: string): number
	if MovementMode == "run" then
		return CharacterBalance.Stamina.SprintCost
	elseif MovementMode == "jog" then
		return CharacterBalance.Stamina.JogCost
	end
	return 0
end

function CharacterFormulas.GetStaminaDrain(MovementMode: string, DeltaTime: number, Multiplier: number?): number
	local CostPerSecond = CharacterFormulas.GetStaminaCost(MovementMode)
	return CostPerSecond * DeltaTime * (Multiplier or 1)
end

function CharacterFormulas.GetStaminaRegen(DeltaTime: number): number
	return CharacterBalance.Stamina.RegenRate * DeltaTime
end

function CharacterFormulas.CanRegenStamina(TimeSinceLastUse: number): boolean
	return TimeSinceLastUse >= CharacterBalance.Stamina.RegenDelay
end

function CharacterFormulas.IsExhausted(CurrentStamina: number): boolean
	return CurrentStamina <= CharacterBalance.Stamina.ExhaustionThreshold
end

function CharacterFormulas.GetHealthRegen(DeltaTime: number): number
	return CharacterBalance.HealthRegen.Rate * DeltaTime
end

function CharacterFormulas.CanRegenHealth(TimeSinceLastDamage: number): boolean
	return TimeSinceLastDamage >= CharacterBalance.HealthRegen.Delay
end

function CharacterFormulas.GetMovementSpeed(MovementMode: string, BaseRunSpeed: number): number
	if MovementMode == "walk" then
		return CharacterBalance.Movement.WalkSpeed
	elseif MovementMode == "jog" then
		return BaseRunSpeed * CharacterBalance.Movement.JogSpeedPercent
	elseif MovementMode == "run" then
		return BaseRunSpeed
	end
	return CharacterBalance.Movement.WalkSpeed
end

function CharacterFormulas.GetHungerDecay(DeltaTime: number): number
	return HungerBalance.Hunger.DecayRate * DeltaTime
end

function CharacterFormulas.GetHungerFromStamina(StaminaUsed: number): number
	return StaminaUsed * HungerBalance.Hunger.StaminaToHungerRatio
end

function CharacterFormulas.IsHungerCritical(CurrentHunger: number): boolean
	return CurrentHunger <= HungerBalance.Hunger.CriticalThreshold
end

function CharacterFormulas.CanGainStats(CurrentHunger: number): boolean
	return CurrentHunger >= HungerBalance.Hunger.StatGainThreshold
end

function CharacterFormulas.GetStatGainMultiplier(CurrentHunger: number): number
	if CharacterFormulas.CanGainStats(CurrentHunger) then
		return HungerBalance.Hunger.StatGainMultiplierNormal
	end
	return HungerBalance.Hunger.StatGainMultiplierStarving
end

function CharacterFormulas.IsLosingMuscle(CurrentHunger: number): boolean
	return CurrentHunger <= HungerBalance.MuscleLoss.Threshold
end

function CharacterFormulas.GetMuscleLoss(DeltaTime: number): number
	return HungerBalance.MuscleLoss.RatePerSecond * DeltaTime
end

function CharacterFormulas.GetFatigueGain(XPGained: number): number
	return XPGained * FatigueBalance.Fatigue.XPToFatigueRatio
end

function CharacterFormulas.IsTrainingLocked(CurrentFatigue: number): boolean
	local FatiguePercent = (CurrentFatigue / FatigueBalance.Fatigue.MaxFatigue) * 100
	return FatiguePercent >= FatigueBalance.Fatigue.TrainingLockoutPercent
end

function CharacterFormulas.GetRestRecoveryRate(IsPremium: boolean?): number
	local TimeToFull = if IsPremium
		then FatigueBalance.Rest.PremiumTimeToFullRest
		else FatigueBalance.Rest.TimeToFullRest
	return FatigueBalance.Fatigue.MaxFatigue / TimeToFull
end

function CharacterFormulas.GetTrainingStaminaDrain(StatName: string, DeltaTime: number): number
	local TrainingType = TrainingTypesBalance[StatName]
	if not TrainingType then
		return 0
	end
	return TrainingType.StaminaDrain * DeltaTime
end

function CharacterFormulas.GetTrainingXP(StatName: string, DeltaTime: number, IsMachine: boolean?): number
	local TrainingType = TrainingTypesBalance[StatName]
	if not TrainingType then
		return 0
	end

	local BaseXP = TrainingType.BaseXPPerSecond * DeltaTime

	if not IsMachine and TrainingType.NonmachineMultiplier then
		BaseXP = BaseXP * TrainingType.NonmachineMultiplier
	end

	return BaseXP
end

function CharacterFormulas.IsSweatActive(StaminaPercent: number, TimeSinceActivity: number): boolean
	local BelowThreshold = StaminaPercent <= HungerBalance.Sweat.StaminaThresholdPercent
	local RecentActivity = TimeSinceActivity <= HungerBalance.Sweat.ActivityTimeoutSeconds
	return BelowThreshold and RecentActivity
end

function CharacterFormulas.GetSweatStatMultiplier(): number
	return HungerBalance.Sweat.StatGainMultiplier
end

function CharacterFormulas.GetSweatHungerMultiplier(): number
	return HungerBalance.Sweat.HungerDrainMultiplier
end

return CharacterFormulas