--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")

local Maid = require(Shared.General.Maid)
local EventBus = require(Server.Core.EventBus)
local EntityEvents = require(Shared.Events.EntityEvents)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local StateComponent = require(Server.Entity.Core.StateComponent)
local StatComponent = require(Server.Entity.Core.StatComponent)
local ModifierComponent = require(Server.Entity.Core.ModifierComponent)

export type EntityData = {
	Character: Model,
	Humanoid: Humanoid,
	IsPlayer: boolean,
	Player: Player?,
	PlayerData: any?,
}

export type Entity = {
	Character: Model,
	Humanoid: Humanoid,
	IsPlayer: boolean,
	Player: Player?,

	States: StateComponent.StateComponent,
	Stats: StatComponent.StatComponent,
	Modifiers: ModifierComponent.ModifierComponent,

	TakeDamage: (self: Entity, Damage: number, Source: Player?, Direction: Vector3?) -> (),
	DealDamage: (self: Entity, Target: Model, BaseDamage: number) -> (),
	Destroy: (self: Entity) -> (),
	GetComponent: <T>(self: Entity, ComponentName: string) -> T?,
}

type EntityInternal = Entity & {
	Maid: Maid.MaidSelf,
	Components: { [string]: any },
}

local Entity = {}
Entity.__index = Entity

local EntityRegistry: { [Model]: Entity } = {}

function Entity.GetEntity(Character: Model): Entity?
	return EntityRegistry[Character]
end

function Entity.new(Data: EntityData): Entity
	local self: EntityInternal = setmetatable({
		Character = Data.Character,
		Humanoid = Data.Humanoid,
		IsPlayer = Data.IsPlayer,
		Player = Data.Player,

		Maid = Maid.new(),
		Components = {},

		States = nil :: any,
		Stats = nil :: any,
		Modifiers = nil :: any,
	}, Entity) :: any

	self.States = StateComponent.new(self)
	self.Stats = StatComponent.new(self, Data.PlayerData)
	self.Modifiers = ModifierComponent.new(self)

	self.Components.States = self.States
	self.Components.Stats = self.Stats
	self.Components.Modifiers = self.Modifiers

	self.Maid:GiveTask(self.States)
	self.Maid:GiveTask(self.Stats)
	self.Maid:GiveTask(self.Modifiers)

	self.Character:SetAttribute("HasEntity", true)
	EntityRegistry[self.Character] = self

	self.Maid:GiveTask(self.Humanoid.Died:Connect(function()
		self:Destroy()
	end))

	self.Maid:GiveTask(self.Humanoid.HealthChanged:Connect(function()
		self.Stats:SetStat("Health", self.Humanoid.Health)
	end))

	EventBus.Publish(EntityEvents.ENTITY_CREATED, {
		Entity = self,
		Character = self.Character,
		IsPlayer = self.IsPlayer,
		Player = self.Player,
		PlayerData = Data.PlayerData,
	})

	return self
end

function Entity:GetComponent<T>(ComponentName: string): T?
	return self.Components[ComponentName] :: T?
end

function Entity:TakeDamage(Damage: number, Source: Player?, Direction: Vector3?)
	local ModifiedDamage = self.Modifiers:Apply("Damage", Damage, {
		Source = Source,
		Direction = Direction,
		OriginalDamage = Damage,
	})

	if self.States:GetState(StateTypes.INVULNERABLE) then
		return
	end

	if self.States:GetState(StateTypes.BLOCKING) then
		ModifiedDamage = ModifiedDamage * (1 - CombatBalance.Blocking.DAMAGE_REDUCTION)
	end

	self.Humanoid.Health -= ModifiedDamage
	local CurrentHealth = self.Humanoid.Health
	self.Stats:SetStat("Health", CurrentHealth)
end

function Entity:DealDamage(Target: Model, BaseDamage: number)
	local FinalDamage = self.Modifiers:Apply("Attack", BaseDamage, {
		Target = Target,
	})

	local TargetEntity = Entity.GetEntity(Target)
	if TargetEntity then
		TargetEntity:TakeDamage(FinalDamage, self.Player)
	end
end

function Entity:Destroy()
	EventBus.Publish(EntityEvents.ENTITY_DESTROYED, {
		Entity = self,
		Character = self.Character,
	})

	EntityRegistry[self.Character] = nil
	self.Maid:DoCleaning()
	table.clear(self.Components)
end

return Entity
