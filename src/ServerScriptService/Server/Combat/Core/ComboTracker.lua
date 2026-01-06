--!strict

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local CombatEvents = require(script.Parent.Parent.CombatEvents)

type Entity = CombatTypes.Entity

local ComboTracker = {}

local EntityComboCounts: { [Entity]: { [string]: number } } = {}
local EntityComboTimers: { [Entity]: { [string]: number } } = {}
local EntityResetThreads: { [Entity]: { [string]: thread } } = {}

local DEFAULT_COMBO_RESET_TIME = 2.0

local PublishEvent: ((EventName: string, Data: { [string]: any }) -> ())?

function ComboTracker.SetEventPublisher(Publisher: (EventName: string, Data: { [string]: any }) -> ())
	PublishEvent = Publisher
end

local function FireEvent(EventName: string, Data: { [string]: any })
	if PublishEvent then
		PublishEvent(EventName, Data)
	end
end

function ComboTracker.GetCount(Entity: Entity, ActionName: string): number
	local Counts = EntityComboCounts[Entity]
	if not Counts then
		return 1
	end

	return Counts[ActionName] or 1
end

function ComboTracker.Advance(Entity: Entity, ActionName: string, CurrentIndex: number, MaxIndex: number, ResetTime: number?)
	EntityComboCounts[Entity] = EntityComboCounts[Entity] or {}
	EntityComboTimers[Entity] = EntityComboTimers[Entity] or {}
	EntityResetThreads[Entity] = EntityResetThreads[Entity] or {}

	local NextIndex = if CurrentIndex >= MaxIndex then 1 else CurrentIndex + 1
	EntityComboCounts[Entity][ActionName] = NextIndex
	EntityComboTimers[Entity][ActionName] = workspace:GetServerTimeNow()

	if Entity.Character then
		Entity.Character:SetAttribute(ActionName .. "ComboCount", NextIndex)
	end

	FireEvent(CombatEvents.ComboAdvanced, {
		Entity = Entity,
		ActionName = ActionName,
		PreviousIndex = CurrentIndex,
		NewIndex = NextIndex,
		MaxIndex = MaxIndex,
	})

	local ExistingThread = EntityResetThreads[Entity][ActionName]
	if ExistingThread then
		local Status = coroutine.status(ExistingThread)
		if Status == "suspended" then
			task.cancel(ExistingThread)
		end
	end

	local FinalResetTime = ResetTime or DEFAULT_COMBO_RESET_TIME

	local ResetThread = task.delay(FinalResetTime, function()
		local Timers = EntityComboTimers[Entity]
		if not Timers then
			return
		end

		local LastTime = Timers[ActionName]
		if not LastTime then
			return
		end

		if (workspace:GetServerTimeNow() - LastTime) >= FinalResetTime then
			ComboTracker.Reset(Entity, ActionName)
		end
	end)

	EntityResetThreads[Entity][ActionName] = ResetThread
end

function ComboTracker.Reset(Entity: Entity, ActionName: string)
	local Counts = EntityComboCounts[Entity]
	if Counts then
		Counts[ActionName] = 1
	end

	if Entity.Character then
		Entity.Character:SetAttribute(ActionName .. "ComboCount", 1)
	end

	local Threads = EntityResetThreads[Entity]
	if Threads and Threads[ActionName] then
		local Status = coroutine.status(Threads[ActionName])
		if Status == "suspended" then
			task.cancel(Threads[ActionName])
		end
		Threads[ActionName] = nil
	end

	FireEvent(CombatEvents.ComboReset, {
		Entity = Entity,
		ActionName = ActionName,
	})
end

function ComboTracker.ResetAll(Entity: Entity)
	local Counts = EntityComboCounts[Entity]
	if Counts then
		for ActionName in Counts do
			ComboTracker.Reset(Entity, ActionName)
		end
	end
end

function ComboTracker.CleanupEntity(Entity: Entity)
	local Threads = EntityResetThreads[Entity]
	if Threads then
		for _, Thread in Threads do
			local Status = coroutine.status(Thread)
			if Status == "suspended" then
				task.cancel(Thread)
			end
		end
	end

	EntityComboCounts[Entity] = nil
	EntityComboTimers[Entity] = nil
	EntityResetThreads[Entity] = nil
end

return ComboTracker