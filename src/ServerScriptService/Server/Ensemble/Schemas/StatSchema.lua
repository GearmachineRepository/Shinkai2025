--!strict

local Types = require(script.Parent.Parent.Types)

type ValidationResult = Types.ValidationResult
type ValidationError = Types.ValidationError
type StatConfig = Types.StatConfig

local VALID_REPLICATION_MODES = {
	All = true,
	Owner = true,
	None = true,
}

local StatSchema = {}

function StatSchema.Validate(Config: any): ValidationResult
	local Errors: { ValidationError } = {}

	if type(Config) ~= "table" then
		table.insert(Errors, {
			Field = "Config",
			Message = "StatConfig must be a table",
		})
		return { Valid = false, Errors = Errors }
	end

	if type(Config.Stats) ~= "table" then
		table.insert(Errors, {
			Field = "Stats",
			Message = "StatConfig.Stats must be a table",
		})
		return { Valid = false, Errors = Errors }
	end

	for StatName, StatDefinition in Config.Stats do
		local FieldPrefix = string.format("Stats.%s", StatName)

		if type(StatName) ~= "string" then
			table.insert(Errors, {
				Field = FieldPrefix,
				Message = "Stat name must be a string",
			})
			continue
		end

		if type(StatDefinition) ~= "table" then
			table.insert(Errors, {
				Field = FieldPrefix,
				Message = "Stat definition must be a table",
			})
			continue
		end

		if StatDefinition.Default == nil then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Default",
				Message = "Default is required",
			})
		elseif type(StatDefinition.Default) ~= "number" then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Default",
				Message = "Default must be a number",
			})
		end

		if StatDefinition.Min ~= nil and type(StatDefinition.Min) ~= "number" then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Min",
				Message = "Min must be a number",
			})
		end

		if StatDefinition.Max ~= nil and type(StatDefinition.Max) ~= "number" then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Max",
				Message = "Max must be a number",
			})
		end

		if StatDefinition.Min ~= nil and StatDefinition.Max ~= nil then
			if StatDefinition.Min > StatDefinition.Max then
				table.insert(Errors, {
					Field = FieldPrefix,
					Message = "Min cannot be greater than Max",
				})
			end
		end

		if StatDefinition.Replication == nil then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Replication",
				Message = "Replication is required",
			})
		elseif not VALID_REPLICATION_MODES[StatDefinition.Replication] then
			table.insert(Errors, {
				Field = FieldPrefix .. ".Replication",
				Message = string.format(
					"Replication must be 'All', 'Owner', or 'None', got '%s'",
					tostring(StatDefinition.Replication)
				),
			})
		end
	end

	return {
		Valid = #Errors == 0,
		Errors = Errors,
	}
end

function StatSchema.GetStatNames(Config: StatConfig): { string }
	local Names = {}
	for StatName in Config.Stats do
		table.insert(Names, StatName)
	end
	return Names
end

function StatSchema.GetDefault(Config: StatConfig, StatName: string): number
	local Definition = Config.Stats[StatName]
	if Definition then
		return Definition.Default
	end
	return 0
end

function StatSchema.GetMin(Config: StatConfig, StatName: string): number?
	local Definition = Config.Stats[StatName]
	if Definition then
		return Definition.Min
	end
	return nil
end

function StatSchema.GetMax(Config: StatConfig, StatName: string): number?
	local Definition = Config.Stats[StatName]
	if Definition then
		return Definition.Max
	end
	return nil
end

function StatSchema.GetReplication(Config: StatConfig, StatName: string): string
	local Definition = Config.Stats[StatName]
	if Definition then
		return Definition.Replication
	end
	return "None"
end

function StatSchema.ClampValue(Config: StatConfig, StatName: string, Value: number): number
	local Definition = Config.Stats[StatName]
	if not Definition then
		return Value
	end

	local ClampedValue = Value

	if Definition.Min ~= nil then
		ClampedValue = math.max(Definition.Min, ClampedValue)
	end

	if Definition.Max ~= nil then
		ClampedValue = math.min(Definition.Max, ClampedValue)
	end

	return ClampedValue
end

return StatSchema