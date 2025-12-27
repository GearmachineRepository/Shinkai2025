--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local AnimationTimingCache = require(Server.Combat.AnimationTimingCache)
local CombatTypes = require(Server.Combat.CombatTypes)
local Packets = require(Shared.Networking.Packets)

type ActionContext = CombatTypes.ActionContext
type Entity = CombatTypes.Entity
type ActionMetadata = CombatTypes.ActionMetadata

local M1 = {}

M1.ActionName = "M1"
M1.ActionType = "Attack"

M1.DefaultMetadata = {
	ActionName = "M1",
	BaseDamage = 10,
	StaminaCost = 5,
	HitboxSize = Vector3.new(4, 4, 4),
	HitboxOffset = CFrame.new(0, 0, -3),
	FeintEndlag = 0.25,
    Feintable = true,

	FallbackTimings = {
		HitStart = 0.25,
		HitEnd = 0.55,
		Length = 1.25
	},
}

function M1.CanExecute(Context: ActionContext): (boolean, string?)
	if Context.Metadata == nil then
		return false, "Missing metadata"
	end

	return true, nil
end

function M1.OnStart(Context: ActionContext)
	Context.CustomData.HitWindowOpen = false
	Context.CustomData.HasHit = false
	Context.CustomData.LastHitTarget = nil

	Context.CustomData.CanFeint = true
end

function M1.OnExecute(Context: ActionContext)
	local Metadata = Context.Metadata
	if Metadata == nil then
		return
	end

	local AnimationName = "Karate1"

	if Context.Entity.Player then
		Packets.PlayAnimation:FireClient(Context.Entity.Player, AnimationName)
	end

	local AnimationLength = AnimationTimingCache.GetLength(AnimationName) or Metadata.FallbackTimings.Length
	local HitStartTime = AnimationTimingCache.GetTiming(AnimationName, "HitStart", Metadata.FallbackTimings.HitStart)
	local HitEndTime = AnimationTimingCache.GetTiming(AnimationName, "HitEnd", Metadata.FallbackTimings.HitEnd)

	if not AnimationLength or not HitStartTime or not HitEndTime then
		return
	end

	local StartTimestamp = os.clock()

	local function WaitUntil(AbsoluteSecondsFromStart: number): boolean
		local Elapsed = os.clock() - StartTimestamp
		local Remaining = AbsoluteSecondsFromStart - Elapsed
		if Remaining > 0 then
			task.wait(Remaining)
		end
		return Context.Interrupted ~= true
	end

	if not WaitUntil(HitStartTime) then
		return
	end

	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = true

	if not WaitUntil(HitEndTime) then
		return
	end

	Context.CustomData.HitWindowOpen = false

	if not WaitUntil(AnimationLength) then
		return
	end
end

function M1.OnHit(Context: ActionContext, Target: Entity, HitIndex: number)
	if Context.CustomData.HitWindowOpen ~= true then
		return
	end

	if Context.CustomData.HasHit == true then
		return
	end

	Context.CustomData.HasHit = true
	Context.CustomData.LastHitTarget = Target
	Context.CustomData.LastHitIndex = HitIndex
end

function M1.OnCleanup(Context: ActionContext)
	Context.CustomData.CanFeint = false
	Context.CustomData.HitWindowOpen = false
end

return M1
