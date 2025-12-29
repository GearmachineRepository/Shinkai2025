--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packets = require(ReplicatedStorage.Shared.Networking.Packets)
local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local NetworkService = require(Server.Game.Services.NetworkService)

local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)

local DamageComponent = {}
DamageComponent.__index = DamageComponent

DamageComponent.ComponentName = "Damage"
DamageComponent.Dependencies = { "States", "Stats" }

local PING_THRESHOLD_MS = 70
local MAX_COMP_SECONDS = 0.06
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

function DamageComponent:TakeDamage(Damage: number, Source: Player?, Direction: Vector3?, HitPosition: Vector3?)
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

	if self.Entity.States:GetState(StateTypes.BLOCKING) then
		ModifiedDamage = ModifiedDamage * (1 - CombatBalance.Blocking.DAMAGE_REDUCTION)
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

	local HitType = if self.Entity.States:GetState(StateTypes.BLOCKING) then "BlockHit" else "Hit"

	local SourceUser: number? = nil
	if Source and Source:IsA("Player") then
		SourceUser = Source.UserId
	else
		SourceUser = Source
	end

	Packets.PlayVfxReplicate:Fire(
		SourceUser,
		HitType,
		{
			Target = self.Entity.Character,
			HitPosition = HitPosition,
		}
	)

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
	local TargetPlayer = self.Entity.Player

	if TargetPlayer then
		local DelaySeconds = GetCompDelaySeconds(TargetPlayer)

		if DelaySeconds > 0 then
			task.delay(DelaySeconds, function()
				self:TakeDamage(Damage, Source, Direction, HitPosition)
			end)
			return
		end
	end

	self:TakeDamage(Damage, Source, Direction, HitPosition)
end

function DamageComponent.Destroy(self: Self)
	self.Maid:DoCleaning()
end

return DamageComponent