--!strict

local Signal = require(script.Parent.Signal)
local Types = require(script.Parent.Parent.Types)

type EventConfig = Types.EventConfig

type EventBusInternal = {
	Events: { [string]: Types.Signal<any> },
	EventConfig: EventConfig?,
}

local EventBus: EventBusInternal = {
	Events = {},
	EventConfig = nil,
}

local function GetOrCreateEvent(EventName: string): Types.Signal<any>
	local ExistingEvent = EventBus.Events[EventName]
	if ExistingEvent then
		return ExistingEvent
	end

	local NewEvent = Signal.new()
	EventBus.Events[EventName] = NewEvent
	return NewEvent
end

local Module = {}

function Module.Configure(Config: EventConfig)
	EventBus.EventConfig = Config

	for _, EventName in Config.Events do
		if not EventBus.Events[EventName] then
			EventBus.Events[EventName] = Signal.new()
		end
	end
end

function Module.Subscribe(EventName: string, Callback: (...any) -> ()): Types.Connection
	local Event = GetOrCreateEvent(EventName)
	return Event:Connect(Callback)
end

function Module.SubscribeOnce(EventName: string, Callback: (...any) -> ()): Types.Connection
	local Event = GetOrCreateEvent(EventName)
	return Event:Once(Callback)
end

function Module.Publish(EventName: string, ...: any)
	local Event = EventBus.Events[EventName]
	if Event then
		Event:Fire(...)
	end
end

function Module.Wait(EventName: string): ...any
	local Event = GetOrCreateEvent(EventName)
	return Event:Wait()
end

function Module.Clear(EventName: string?)
	if EventName then
		local Event = EventBus.Events[EventName]
		if Event then
			Event:DisconnectAll()
		end
		EventBus.Events[EventName] = nil
	else
		for _, Event in EventBus.Events do
			Event:DisconnectAll()
		end
		table.clear(EventBus.Events)
	end
end

function Module.HasEvent(EventName: string): boolean
	return EventBus.Events[EventName] ~= nil
end

function Module.GetEventNames(): { string }
	local Names = {}
	for EventName in EventBus.Events do
		table.insert(Names, EventName)
	end
	return Names
end

return Module