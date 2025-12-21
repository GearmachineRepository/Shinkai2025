--!strict

local Types = require(script.Parent.Parent.Types)

type ValidationResult = Types.ValidationResult
type ValidationError = Types.ValidationError
type EventConfig = Types.EventConfig

local REQUIRED_EVENTS = {
	"EntityCreated",
	"EntityDestroyed",
	"StateChanged",
	"StatChanged",
}

local EventSchema = {}

function EventSchema.Validate(Config: any): ValidationResult
	local Errors: { ValidationError } = {}

	if type(Config) ~= "table" then
		table.insert(Errors, {
			Field = "Config",
			Message = "EventConfig must be a table",
		})
		return { Valid = false, Errors = Errors }
	end

	if type(Config.Events) ~= "table" then
		table.insert(Errors, {
			Field = "Events",
			Message = "EventConfig.Events must be an array of strings",
		})
		return { Valid = false, Errors = Errors }
	end

	local EventSet: { [string]: boolean } = {}

	for Index, EventName in Config.Events do
		if type(EventName) ~= "string" then
			table.insert(Errors, {
				Field = string.format("Events[%d]", Index),
				Message = "Event name must be a string",
			})
			continue
		end

		if EventSet[EventName] then
			table.insert(Errors, {
				Field = string.format("Events[%d]", Index),
				Message = string.format("Duplicate event name: '%s'", EventName),
			})
			continue
		end

		EventSet[EventName] = true
	end

	for _, RequiredEvent in REQUIRED_EVENTS do
		if not EventSet[RequiredEvent] then
			table.insert(Errors, {
				Field = "Events",
				Message = string.format("Missing required event: '%s'", RequiredEvent),
			})
		end
	end

	return {
		Valid = #Errors == 0,
		Errors = Errors,
	}
end

function EventSchema.GetEventNames(Config: EventConfig): { string }
	local Names = {}
	for _, EventName in Config.Events do
		table.insert(Names, EventName)
	end
	return Names
end

function EventSchema.HasEvent(Config: EventConfig, EventName: string): boolean
	for _, Name in Config.Events do
		if Name == EventName then
			return true
		end
	end
	return false
end

function EventSchema.GetRequiredEvents(): { string }
	return table.clone(REQUIRED_EVENTS)
end

return EventSchema