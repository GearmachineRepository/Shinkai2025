--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StatusEffectComponent = {}
StatusEffectComponent.__index = StatusEffectComponent

StatusEffectComponent.ComponentName = "StatusEffect"
StatusEffectComponent.Dependencies = { "Modifiers" }
StatusEffectComponent.UpdateRate = 1 / 10

type StatusEffectData = {
	EffectId: string,
	StartTime: number,
	Duration: number,
	Stacks: number,
	ModifierCleanup: (() -> ())?,
	CustomData: { [string]: any }?,
}

type StatusEffectConfig = {
	Stacks: boolean?,
	MaxStacks: number?,
	ModifierType: string?,
	ModifierPriority: number?,
	ModifierFunction: ((BaseValue: number, StackCount: number, CustomData: any?) -> number)?,
	OnApply: ((Entity: Types.Entity, StackCount: number) -> ())?,
	OnRemove: ((Entity: Types.Entity, StackCount: number) -> ())?,
	OnStack: ((Entity: Types.Entity, OldStacks: number, NewStacks: number) -> ())?,
	CustomData: { [string]: any }?,
}

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	ActiveEffects: { [string]: StatusEffectData },
	EffectConfigs: { [string]: StatusEffectConfig },
	UpdateAccumulator: number,
}

local UPDATE_INTERVAL = 0.1

local function GetServerTime(): number
	return workspace:GetServerTimeNow()
end

function StatusEffectComponent.new(Entity: Types.Entity, Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		ActiveEffects = {},
		EffectConfigs = {},
		UpdateAccumulator = 0,
	}, StatusEffectComponent) :: any

	return self
end

function StatusEffectComponent.Apply(self: Self, EffectId: string, Duration: number, Config: StatusEffectConfig?)
	local ExistingEffect = self.ActiveEffects[EffectId]
	local EffectConfig = Config or {}

	self.EffectConfigs[EffectId] = EffectConfig

	if ExistingEffect then
		if EffectConfig.Stacks then
			local MaxStacks = EffectConfig.MaxStacks or 99
			local OldStacks = ExistingEffect.Stacks
			local NewStacks = math.min(ExistingEffect.Stacks + 1, MaxStacks)

			ExistingEffect.Stacks = NewStacks
			ExistingEffect.StartTime = GetServerTime()
			ExistingEffect.Duration = Duration

			if EffectConfig.OnStack then
				EffectConfig.OnStack(self.Entity, OldStacks, NewStacks)
			end

			StatusEffectComponent.UpdateModifier(self, EffectId, ExistingEffect)

			Ensemble.Events.Publish("StatusEffectStacked", {
				Entity = self.Entity,
				EffectId = EffectId,
				Stacks = NewStacks,
				Duration = Duration,
			})
		else
			ExistingEffect.StartTime = GetServerTime()
			ExistingEffect.Duration = Duration
		end
		return
	end

	local NewEffect: StatusEffectData = {
		EffectId = EffectId,
		StartTime = GetServerTime(),
		Duration = Duration,
		Stacks = 1,
		ModifierCleanup = nil,
		CustomData = EffectConfig.CustomData,
	}

	self.ActiveEffects[EffectId] = NewEffect

	if EffectConfig.ModifierType and EffectConfig.ModifierFunction then
		StatusEffectComponent.RegisterModifier(self, EffectId, NewEffect)
	end

	if EffectConfig.OnApply then
		EffectConfig.OnApply(self.Entity, NewEffect.Stacks)
	end

	Ensemble.Events.Publish("StatusEffectApplied", {
		Entity = self.Entity,
		EffectId = EffectId,
		Duration = Duration,
		Stacks = NewEffect.Stacks,
	})

	if self.Entity.Character then
		self.Entity.Character:SetAttribute("Effect_" .. EffectId, true)
	end
end

function StatusEffectComponent.RegisterModifier(self: Self, EffectId: string, Effect: StatusEffectData)
	local Config = self.EffectConfigs[EffectId]
	if not Config or not Config.ModifierType or not Config.ModifierFunction then
		return
	end

	local ModifierFunc = Config.ModifierFunction
	local Cleanup = self.Entity.Modifiers:Register(
		Config.ModifierType,
		Config.ModifierPriority or 100,
		function(BaseValue: number, _Data: { [string]: any }?)
			return ModifierFunc(BaseValue, Effect.Stacks, Effect.CustomData)
		end
	)

	Effect.ModifierCleanup = Cleanup
end

function StatusEffectComponent.UpdateModifier(self: Self, EffectId: string, Effect: StatusEffectData)
	if Effect.ModifierCleanup then
		Effect.ModifierCleanup()
	end
	StatusEffectComponent.RegisterModifier(self, EffectId, Effect)
end

function StatusEffectComponent.Remove(self: Self, EffectId: string)
	local Effect = self.ActiveEffects[EffectId]
	if not Effect then
		return
	end

	if Effect.ModifierCleanup then
		Effect.ModifierCleanup()
	end

	local Config = self.EffectConfigs[EffectId]
	if Config and Config.OnRemove then
		Config.OnRemove(self.Entity, Effect.Stacks)
	end

	Ensemble.Events.Publish("StatusEffectRemoved", {
		Entity = self.Entity,
		EffectId = EffectId,
	})

	if self.Entity.Character then
		self.Entity.Character:SetAttribute("Effect_" .. EffectId, nil)
	end

	self.ActiveEffects[EffectId] = nil
	self.EffectConfigs[EffectId] = nil
end

function StatusEffectComponent.Has(self: Self, EffectId: string): boolean
	return self.ActiveEffects[EffectId] ~= nil
end

function StatusEffectComponent.GetRemaining(self: Self, EffectId: string): number
	local Effect = self.ActiveEffects[EffectId]
	if not Effect then
		return 0
	end

	local Elapsed = GetServerTime() - Effect.StartTime
	local Remaining = Effect.Duration - Elapsed

	return math.max(0, Remaining)
end

function StatusEffectComponent.GetStacks(self: Self, EffectId: string): number
	local Effect = self.ActiveEffects[EffectId]
	return if Effect then Effect.Stacks else 0
end

function StatusEffectComponent.RefreshDuration(self: Self, EffectId: string, NewDuration: number)
	local Effect = self.ActiveEffects[EffectId]
	if not Effect then
		return
	end

	Effect.StartTime = GetServerTime()
	Effect.Duration = NewDuration
end

function StatusEffectComponent.Update(self: Self, DeltaTime: number)
	self.UpdateAccumulator += DeltaTime

	if self.UpdateAccumulator < UPDATE_INTERVAL then
		return
	end

	self.UpdateAccumulator = 0

	local CurrentTime = GetServerTime()
	local EffectsToRemove = {}

	for EffectId, Effect in self.ActiveEffects do
		local Elapsed = CurrentTime - Effect.StartTime
		if Elapsed >= Effect.Duration then
			table.insert(EffectsToRemove, EffectId)
		end
	end

	for _, EffectId in EffectsToRemove do
		StatusEffectComponent.Remove(self, EffectId)
	end
end

function StatusEffectComponent.Destroy(self: Self)
	for EffectId in pairs(self.ActiveEffects) do
		StatusEffectComponent.Remove(self, EffectId)
	end

	self.Maid:DoCleaning()
	table.clear(self.ActiveEffects)
	table.clear(self.EffectConfigs)
end

return StatusEffectComponent