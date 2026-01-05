--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local StateTypes = require(Shared.Config.Enums.StateTypes)

local DamageComponent = {}
DamageComponent.__index = DamageComponent

DamageComponent.ComponentName = "Damage"
DamageComponent.Dependencies = { "States", "Stats" }

local ON_HIT_HOLD_SECONDS = 0.1

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
}

function DamageComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
	}, DamageComponent) :: any

	return self
end

function DamageComponent:TakeDamage(Damage: number, Source: Player?, Direction: Vector3?)
	if self.Entity.States:GetState(StateTypes.INVULNERABLE) then
		return
	end

	local ModifiedDamage = Damage :: number

	if self.Entity.Modifiers then
		ModifiedDamage = self.Entity.Modifiers:Apply("Damage", Damage, {
			Source = Source,
			Direction = Direction,
			OriginalDamage = Damage,
		})
	end

	local CurrentHealth = (self.Entity.Humanoid.Health :: number) - ModifiedDamage
	self.Entity.Humanoid.Health = math.max(0, CurrentHealth)
	self.Entity.Stats:SetStat("Health", self.Entity.Humanoid.Health)

	local OnHitCountAttributeName = "OnHitCount"
	local CurrentOnHitCountValue = self.Entity.Character:GetAttribute(OnHitCountAttributeName)
	local CurrentOnHitCount = if typeof(CurrentOnHitCountValue) == "number" then CurrentOnHitCountValue else 0

	CurrentOnHitCount += 1
	self.Entity.Character:SetAttribute(OnHitCountAttributeName, CurrentOnHitCount)
	self.Entity.States:SetState(StateTypes.ONHIT, true)

	task.delay(ON_HIT_HOLD_SECONDS, function()
		if not self.Entity.Character or not self.Entity.Character.Parent then
			return
		end

		local UpdatedOnHitCountValue = self.Entity.Character:GetAttribute(OnHitCountAttributeName)
		local UpdatedOnHitCount = if typeof(UpdatedOnHitCountValue) == "number" then UpdatedOnHitCountValue else 0

		UpdatedOnHitCount = math.max(0, UpdatedOnHitCount - 1)
		self.Entity.Character:SetAttribute(OnHitCountAttributeName, UpdatedOnHitCount)

		if UpdatedOnHitCount == 0 then
			self.Entity.States:SetState(StateTypes.ONHIT, false)
		end
	end)
end

function DamageComponent:DealDamage(Damage: number, Source: Player?, Direction: Vector3?, HitPosition: Vector3?)
	self:TakeDamage(Damage, Source, Direction, HitPosition)
end

function DamageComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return DamageComponent