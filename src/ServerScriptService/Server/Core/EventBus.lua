--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Packages.Signal)

export type EventCallback = (...any) -> ()
export type EventConnection = {
	Disconnect: () -> (),
	Connected: boolean,
}

export type EventBus = {
	Subscribe: (EventName: string, Callback: EventCallback) -> EventConnection,
	Publish: (EventName: string, ...any) -> (),
	Clear: (EventName: string?) -> (),
}

local Events: { [string]: any } = {}

local EventBus: EventBus = {} :: any

function EventBus.Subscribe(EventName: string, Callback: EventCallback): EventConnection
	local Event = Events[EventName]
	if not Event then
		Event = Signal.new()
		Events[EventName] = Event
	end

	return Event:Connect(Callback)
end

function EventBus.Publish(EventName: string, ...: any)
	local Event = Events[EventName]
	if Event then
		Event:Fire(...)
	end
end

function EventBus.Clear(EventName: string?)
	if EventName then
		local Event = Events[EventName]
		if Event and Event.DisconnectAll then
			Event:DisconnectAll()
		end
		Events[EventName] = nil
	else
		for _, Event in Events do
			if Event.DisconnectAll then
				Event:DisconnectAll()
			end
		end
		table.clear(Events)
	end
end

return EventBus
