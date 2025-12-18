--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Maid = require(Shared.General.Maid)
local EventBus = require(Server.Framework.Utilities.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)

type StatusEffectData = {
	EffectId: string,
	StartTime: number,
	Duration: number,
	Stacks: number,
	ModifierCleanup: (() -> ())?,
	CustomData: { [string]: any }?,
}

export type StatusEffectComponent = {
	Entity: any,

	Apply: (self: StatusEffectComponent, EffectId: string, Duration: number, Config: StatusEffectConfig?) -> (),
	Remove: (self: StatusEffectComponent, EffectId: string) -> (),
	Has: (self: StatusEffectComponent, EffectId: string) -> boolean,
	GetRemaining: (self: StatusEffectComponent, EffectId: string) -> number,
	GetStacks: (self: StatusEffectComponent, EffectId: string) -> number,
	RefreshDuration: (self: StatusEffectComponent, EffectId: string, NewDuration: number) -> (),
	Update: (self: StatusEffectComponent, DeltaTime: number) -> (),
	Destroy: (self: StatusEffectComponent) -> (),
}

export type StatusEffectConfig = {
	Stacks: boolean,
	MaxStacks: number,
	ModifierType: string,
	ModifierPriority: number,
	ModifierFunction: (BaseValue: number, StackCount: number, CustomData: any?) -> number,
	OnApply: (Entity: any, StackCount: number) -> (),
	OnRemove: (Entity: any, StackCount: number) -> (),
	OnStack: (Entity: any, OldStacks: number, NewStacks: number) -> (),
	CustomData: { [string]: any },
}

type StatusEffectComponentInternal = StatusEffectComponent & {
	ActiveEffects: { [string]: StatusEffectData },
	EffectConfigs: { [string]: StatusEffectConfig },
	Maid: Maid.MaidSelf,
	UpdateAccumulator: number,
}

local StatusEffectComponent = {}
StatusEffectComponent.__index = StatusEffectComponent

local UPDATE_INTERVAL = 0.1

local function GetServerTime(): number
	return workspace:GetServerTimeNow()
end

function StatusEffectComponent.new(Entity: any): StatusEffectComponent
	local self: StatusEffectComponentInternal = setmetatable({
		Entity = Entity,
		ActiveEffects = {},
		EffectConfigs = {},
		Maid = Maid.new(),
		UpdateAccumulator = 0,
	}, StatusEffectComponent) :: any

	return self
end

function StatusEffectComponent:Apply(EffectId: string, Duration: number, Config: StatusEffectConfig?)
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

			self:UpdateModifier(EffectId, ExistingEffect)

			EventBus.Publish(EntityEvents.STATUS_EFFECT_STACKED, {
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
		self:RegisterModifier(EffectId, NewEffect)
	end

	if EffectConfig.OnApply then
		EffectConfig.OnApply(self.Entity, NewEffect.Stacks)
	end

	EventBus.Publish(EntityEvents.STATUS_EFFECT_APPLIED, {
		Entity = self.Entity,
		EffectId = EffectId,
		Duration = Duration,
		Stacks = NewEffect.Stacks,
	})

	if self.Entity.Character then
		self.Entity.Character:SetAttribute("Effect_" .. EffectId, true)
	end
end

function StatusEffectComponent:RegisterModifier(EffectId: string, Effect: StatusEffectData)
	local Config = self.EffectConfigs[EffectId]
	if not Config or not Config.ModifierType or not Config.ModifierFunction then
		return
	end

	local Cleanup = self.Entity.Modifiers:Register(
		Config.ModifierType,
		Config.ModifierPriority or 100,
		function(BaseValue: number, _Data: { [string]: any }?)
			return Config.ModifierFunction(BaseValue, Effect.Stacks, Effect.CustomData)
		end
	)

	Effect.ModifierCleanup = Cleanup
end

function StatusEffectComponent:UpdateModifier(EffectId: string, Effect: StatusEffectData)
	if Effect.ModifierCleanup then
		Effect.ModifierCleanup()
	end
	self:RegisterModifier(EffectId, Effect)
end

function StatusEffectComponent:Remove(EffectId: string)
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

	EventBus.Publish(EntityEvents.STATUS_EFFECT_REMOVED, {
		Entity = self.Entity,
		EffectId = EffectId,
	})

	if self.Entity.Character then
		self.Entity.Character:SetAttribute("Effect_" .. EffectId, nil)
	end

	self.ActiveEffects[EffectId] = nil
	self.EffectConfigs[EffectId] = nil
end

function StatusEffectComponent:Has(EffectId: string): boolean
	return self.ActiveEffects[EffectId] ~= nil
end

function StatusEffectComponent:GetRemaining(EffectId: string): number
	local Effect = self.ActiveEffects[EffectId]
	if not Effect then
		return 0
	end

	local Elapsed = GetServerTime() - Effect.StartTime
	local Remaining = Effect.Duration - Elapsed

	return math.max(0, Remaining)
end

function StatusEffectComponent:GetStacks(EffectId: string): number
	local Effect = self.ActiveEffects[EffectId]
	return if Effect then Effect.Stacks else 0
end

function StatusEffectComponent:RefreshDuration(EffectId: string, NewDuration: number)
	local Effect = self.ActiveEffects[EffectId]
	if not Effect then
		return
	end

	Effect.StartTime = GetServerTime()
	Effect.Duration = NewDuration
end

function StatusEffectComponent:Update(DeltaTime: number)
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
		self:Remove(EffectId)
	end
end

function StatusEffectComponent:Destroy()
	for EffectId in pairs(self.ActiveEffects) do
		self:Remove(EffectId)
	end

	self.Maid:DoCleaning()
	table.clear(self.ActiveEffects)
	table.clear(self.EffectConfigs)
end

return StatusEffectComponent
