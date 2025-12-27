--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local NetworkService = require(Server.Game.Systems.NetworkService)

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)

local DamageComponent = {}
DamageComponent.__index = DamageComponent

DamageComponent.ComponentName = "Damage"
DamageComponent.Dependencies = { "States" }
DamageComponent.UpdateRate = 1

local PING_THRESHOLD_MS = 70
local MAX_COMP_SECONDS = 0.06

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

local function GetCompDelaySeconds(TargetPlayer: Player?): number
	if not TargetPlayer then
		return 0
	end

	local SmoothedPingMs = NetworkService.GetPingMs(TargetPlayer)
	if type(SmoothedPingMs) ~= "number" then
		return 0
	end

	if SmoothedPingMs < PING_THRESHOLD_MS then
		return 0
	end

	local RawDelaySeconds = (SmoothedPingMs - PING_THRESHOLD_MS) / 1000
	return math.min(RawDelaySeconds, MAX_COMP_SECONDS)
end

function DamageComponent:TakeDamage(Damage: number, Source: Player?, Direction: Vector3?)
	local ModifiedDamage: number = self.Modifiers:Apply("Damage", Damage, {
		Source = Source,
		Direction = Direction,
		OriginalDamage = Damage,
	})

    if self.Entity.States:GetState(StateTypes.INVULNERABLE) then
		return
	end

   	if self.States:GetState(StateTypes.BLOCKING) then
		ModifiedDamage = ModifiedDamage * (1 - CombatBalance.Blocking.DAMAGE_REDUCTION)
	end

	local Health: number = self.Humanoid.Health
	Health -= ModifiedDamage
	self.Humanoid.Health = math.max(0, Health)

	local CurrentHealth = self.Humanoid.Health
	self.Stats:SetStat("Health", CurrentHealth)
end

function DamageComponent:TakeDamageCompensated(Damage: number, Source: Player?, Direction: Vector3?)
	local DelaySeconds = GetCompDelaySeconds(self.Player)

	if DelaySeconds <= 0 then
		self:TakeDamage(Damage, Source, Direction)
		return
	end

	task.delay(DelaySeconds, function()
		self:TakeDamage(Damage, Source, Direction)
	end)
end

function DamageComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return DamageComponent