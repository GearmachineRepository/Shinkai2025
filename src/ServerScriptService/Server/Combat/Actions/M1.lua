--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local CombatTypes = require(Server.Combat.CombatTypes)

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
    Feintable = true,

	FallbackTimings = {
		HitStart = 0.25,
		HitEnd = 0.55,
	},
}

local function GetTiming(Metadata: ActionMetadata, TimingName: string, FallbackValue: number): number
	local FallbackTimingsValue = Metadata.FallbackTimings
	if type(FallbackTimingsValue) == "table" then
		local TimingValue = (FallbackTimingsValue :: { [string]: any })[TimingName]
		if type(TimingValue) == "number" then
			return TimingValue
		end
	end
	return FallbackValue
end

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

	local HitStartTime = GetTiming(Metadata, "HitStart", 0.15)
	local HitEndTime = GetTiming(Metadata, "HitEnd", 0.35)

	local WindowDuration = math.max(0, HitEndTime - HitStartTime)

	task.wait(HitStartTime)
	if Context.Interrupted then
		return
	end

	Context.CustomData.CanFeint = false

	Context.CustomData.HitWindowOpen = true

	task.wait(WindowDuration)
	if Context.Interrupted then
		return
	end

	Context.CustomData.HitWindowOpen = false
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
