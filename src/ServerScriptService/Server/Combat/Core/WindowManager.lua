--!strict

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)
local CooldownManager = require(script.Parent.Parent.Utility.CooldownManager)
local ThreadScheduler = require(script.Parent.Parent.Utility.ThreadScheduler)
local AngleValidator = require(script.Parent.Parent.Utility.AngleValidator)
local LatencyCompensation = require(script.Parent.Parent.Utility.LatencyCompensation)

type Entity = CombatTypes.Entity
type ActionContext = CombatTypes.ActionContext
type WindowData = CombatTypes.WindowData
type WindowDefinition = CombatTypes.WindowDefinition

local WindowManager = {}

local RegisteredWindows: { [string]: WindowDefinition } = {}

local PublishEvent: ((EventName: string, Data: { [string]: any }) -> ())?

function WindowManager.SetEventPublisher(Publisher: (EventName: string, Data: { [string]: any }) -> ())
	PublishEvent = Publisher
end

local function FireEvent(EventName: string, Data: { [string]: any })
	if PublishEvent then
		PublishEvent(EventName, Data)
	end
end

function WindowManager.Register(Definition: WindowDefinition)
	if not Definition.WindowType then
		warn("[WindowManager] Cannot register window without WindowType")
		return
	end

	RegisteredWindows[Definition.WindowType] = Definition
end

function WindowManager.Unregister(WindowType: string)
	RegisteredWindows[WindowType] = nil
end

function WindowManager.GetDefinition(WindowType: string): WindowDefinition?
	return RegisteredWindows[WindowType]
end

function WindowManager.Open(Context: ActionContext, WindowType: string, InputTimestamp: number?): boolean
	local Entity = Context.Entity

	if Context.ActiveWindow then
		return false
	end

	local Definition = RegisteredWindows[WindowType]
	if not Definition then
		warn("[WindowManager] Unknown window type: " .. WindowType)
		return false
	end

	if CooldownManager.IsOnCooldown(Entity, WindowType, Definition.Cooldown) then
		return false
	end

	local FailureCooldownId = WindowType .. "Failure"
	if CooldownManager.IsOnCooldown(Entity, FailureCooldownId, Definition.SpamCooldown) then
		return false
	end

	local AttemptCooldownId = WindowType .. "Attempt"
	local AttemptCooldown = 0.15
	if CooldownManager.IsOnCooldown(Entity, AttemptCooldownId, AttemptCooldown) then
		return false
	end

	CooldownManager.Start(Entity, AttemptCooldownId, AttemptCooldown)

	local Compensation = LatencyCompensation.GetCompensation(InputTimestamp)
	local AdjustedDuration = Definition.Duration + Compensation

	local WindowData: WindowData = {
		WindowType = WindowType,
		StartTime = workspace:GetServerTimeNow(),
		Duration = AdjustedDuration,
		ExpiryThread = nil,
	}

	Context.ActiveWindow = WindowData
	Entity.States:SetState(Definition.StateName, true)

	FireEvent(CombatEvents.WindowOpened, {
		Entity = Entity,
		WindowType = WindowType,
		Duration = AdjustedDuration,
		Context = Context,
	})

	local ExpiryThread = ThreadScheduler.Schedule(Context, AdjustedDuration, function()
		if CooldownManager.IsOnCooldown(Entity, WindowType, Definition.Cooldown) then
			return
		end

		if not Context.ActiveWindow or Context.ActiveWindow.WindowType ~= WindowType then
			return
		end

		Context.ActiveWindow = nil
		Entity.States:SetState(Definition.StateName, false)

		CooldownManager.Start(Entity, FailureCooldownId, Definition.SpamCooldown)

		if Definition.OnExpire then
			Definition.OnExpire(Context)
		end

		FireEvent(CombatEvents.WindowClosed, {
			Entity = Entity,
			WindowType = WindowType,
			DidTrigger = false,
			Context = Context,
		})
	end, true)

	WindowData.ExpiryThread = ExpiryThread

	return true
end

function WindowManager.Trigger(Context: ActionContext, Attacker: Entity): boolean
	if not Context.ActiveWindow then
		return false
	end

	local WindowType = Context.ActiveWindow.WindowType
	local Definition = RegisteredWindows[WindowType]

	if not Definition then
		return false
	end

	if Definition.MaxAngle then
		local HalfAngle = Definition.MaxAngle / 2
		local DefenderCharacter = Context.Entity.Character
		local AttackerCharacter = Attacker.Character

		if DefenderCharacter and AttackerCharacter then
			if not AngleValidator.IsWithinAngle(DefenderCharacter, AttackerCharacter, HalfAngle) then
				return false
			end
		end
	end

	if Context.ActiveWindow.ExpiryThread then
		local Status = coroutine.status(Context.ActiveWindow.ExpiryThread)
		if Status == "suspended" then
			task.cancel(Context.ActiveWindow.ExpiryThread)
		end
	end

	Context.ActiveWindow = nil
	Context.Entity.States:SetState(Definition.StateName, false)

	CooldownManager.Start(Context.Entity, WindowType, Definition.Cooldown)

	Definition.OnTrigger(Context, Attacker)

	FireEvent(CombatEvents.WindowTriggered, {
		Entity = Context.Entity,
		WindowType = WindowType,
		Attacker = Attacker,
		Context = Context,
	})

	return true
end

function WindowManager.Close(Context: ActionContext)
	if not Context.ActiveWindow then
		return
	end

	local WindowType = Context.ActiveWindow.WindowType
	local Definition = RegisteredWindows[WindowType]

	if Context.ActiveWindow.ExpiryThread then
		local Status = coroutine.status(Context.ActiveWindow.ExpiryThread)
		if Status == "suspended" then
			task.cancel(Context.ActiveWindow.ExpiryThread)
		end
	end

	if Definition then
		local FailureCooldownId = WindowType .. "Failure"
		CooldownManager.Start(Context.Entity, FailureCooldownId, Definition.SpamCooldown)
	end

	Context.ActiveWindow = nil

	if Definition then
		Context.Entity.States:SetState(Definition.StateName, false)
	end
end

function WindowManager.HasActiveWindow(Context: ActionContext): boolean
	return Context.ActiveWindow ~= nil
end

function WindowManager.GetActiveWindowType(Context: ActionContext): string?
	if Context.ActiveWindow then
		return Context.ActiveWindow.WindowType
	end
	return nil
end

function WindowManager.GetAllRegisteredTypes(): { string }
	local Types = {}
	for WindowType in RegisteredWindows do
		table.insert(Types, WindowType)
	end
	return Types
end

return WindowManager