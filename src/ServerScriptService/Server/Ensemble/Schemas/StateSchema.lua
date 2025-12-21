--!strict

local Types = require(script.Parent.Parent.Types)

type ValidationResult = Types.ValidationResult
type ValidationError = Types.ValidationError
type StateConfig = Types.StateConfig

local VALID_REPLICATION_MODES = {
	All = true,
	Owner = true,
	None = true,
}

local StateSchema = {}

function StateSchema.Validate(Config: any): ValidationResult
	local Errors: { ValidationError } = {}

	if type(Config) ~= "table" then
		table.insert(Errors, {
			Field = "Config",
			Message = "StateConfig must be a table",
		})
		return { Valid = false, Errors = Errors }
	end

	if type(Config.States) ~= "table" then
		table.insert(Errors, {
			Field = "States",
			Message = "StateConfig.States must be a table",
		})
		return { Valid = false, Errors = Errors }
	end

	for StateName, StateDefinition in Config.States do
		local FieldPrefix = string.format("States.%s", StateName)

		if type(StateName) ~= "string" then
			table.insert(Errors, {
				Field = FieldPrefix,
				Message = "State name must be a string",
			})
			continue
		end

		if type(StateDefinition) ~= "table" then
			table.insert(Errors, {
				Field = FieldPrefix,
				Message = "State definition must be a table",
			})
			continue
		end

		if StateDefinition.Default ~= nil and type(StateDefinition.Default) ~= "boolean" then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Default",
				Message = "Default must be a boolean",
			})
		end

		if StateDefinition.Replication == nil then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Replication",
				Message = "Replication is required",
			})
		elseif not VALID_REPLICATION_MODES[StateDefinition.Replication] then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Replication",
				Message = string.format(
					"Replication must be 'All', 'Owner', or 'None', got '%s'",
					tostring(StateDefinition.Replication)
				),
			})
		end

		if StateDefinition.Conflicts ~= nil then
			if type(StateDefinition.Conflicts) ~= "table" then
				table.insert(Errors, {
					Field = FieldPrefix .. ".Conflicts",
					Message = "Conflicts must be an array of state names",
				})
			else
				for Index, ConflictName in StateDefinition.Conflicts do
					if type(ConflictName) ~= "string" then
						table.insert(Errors, {
							Field = string.format("%s.Conflicts[%d]", FieldPrefix, Index),
							Message = "Conflict name must be a string",
						})
					end
				end
			end
		end

		if StateDefinition.LockMovement ~= nil and type(StateDefinition.LockMovement) ~= "boolean" then
			table.insert(Errors, {
				Field = FieldPrefix .. ".LockMovement",
				Message = "LockMovement must be a boolean",
			})
		end
	end

	return {
		Valid = #Errors == 0,
		Errors = Errors,
	}
end

function StateSchema.GetStateNames(Config: StateConfig): { string }
	local Names = {}
	for StateName in Config.States do
		table.insert(Names, StateName)
	end
	return Names
end

function StateSchema.GetConflicts(Config: StateConfig, StateName: string): { string }
	local Definition = Config.States[StateName]
	if Definition and Definition.Conflicts then
		return Definition.Conflicts
	end
	return {}
end

function StateSchema.GetReplication(Config: StateConfig, StateName: string): string
	local Definition = Config.States[StateName]
	if Definition then
		return Definition.Replication
	end
	return "None"
end

function StateSchema.GetDefault(Config: StateConfig, StateName: string): boolean
	local Definition = Config.States[StateName]
	if Definition and Definition.Default ~= nil then
		return Definition.Default
	end
	return false
end

function StateSchema.LocksMovement(Config: StateConfig, StateName: string): boolean
	local Definition = Config.States[StateName]
	if Definition and Definition.LockMovement then
		return true
	end
	return false
end

return StateSchema