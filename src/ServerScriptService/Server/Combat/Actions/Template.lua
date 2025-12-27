--!strict
local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local CombatTypes = require(Server.Combat.CombatTypes)

type ActionContext = CombatTypes.ActionContext

local Template = {}

Template.ActionName = "M1"
Template.ActionType = "Attack"

Template.DefaultMetadata = {
    ActionName = "M1",
    BaseDamage = 10,
    StaminaCost = 5,
    HitboxSize = Vector3.new(4, 4, 4),
    HitboxOffset = CFrame.new(0, 0, -3),

    FallbackTimings = {
        HitStart = 0.15,
        HitEnd = 0.35,
    },
}
-- Context.Metadata = the actual item stats
-- Context.CustomData = runtime variables that can be used in the module

-- Returns whether the action is allowed to begin right now (e.g., cooldowns, state gates, stamina checks).
function Template.CanExecute(Context: ActionContext): (boolean, string?)
	return true, nil
end

-- Runs once when the action is accepted and becomes the active action (before OnExecute).
function Template.OnStart(Context: ActionContext)
end

-- Runs the core action logic (typically where timing windows are scheduled and hit detection is driven).
function Template.OnExecute(Context: ActionContext)

end

-- Runs when this action registers a hit on a target (damage, effects, hit reactions, etc.).
function Template.OnHit(Context: ActionContext, Target: any)
end

-- Runs once after successful completion (only when not interrupted).
function Template.OnComplete(Context: ActionContext)
end

-- Runs once during teardown regardless of completion vs interruption (disconnects, cleanup state).
function Template.OnCleanup(Context: ActionContext)
end

return Template
