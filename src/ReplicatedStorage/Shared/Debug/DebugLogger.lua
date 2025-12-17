--!strict

local LOG_LEVEL_INFO = 1
local LOG_LEVEL_WARNING = 2
local LOG_LEVEL_ERROR = 3

type LogLevel = number

local Logger = {}

local CurrentLogLevel: LogLevel = LOG_LEVEL_INFO
local EnableTimestamps: boolean = true

local DebuggingEnabled: boolean = true

local LogPrefix: string = "[Game]"

function Logger.SetLogLevel(Level: LogLevel)
	CurrentLogLevel = Level
end

function Logger.SetPrefix(Prefix: string)
	LogPrefix = Prefix
end

function Logger.EnableTimestamps(Enabled: boolean)
	EnableTimestamps = Enabled
end

local function FormatMessage(Level: string, ScriptName: string?, Message: string): string
	local Parts = {}

	if EnableTimestamps then
		table.insert(Parts, os.date("[%H:%M:%S]"))
	end

	table.insert(Parts, LogPrefix)
	table.insert(Parts, string.format("[%s]", Level))

	if ScriptName then
		table.insert(Parts, string.format("[%s]", ScriptName))
	end

	table.insert(Parts, Message)

	return table.concat(Parts, " ")
end

function Logger.Info(ScriptName: string?, Message: string, ...: any)
	if not DebuggingEnabled then
		return
	end
	if CurrentLogLevel > LOG_LEVEL_INFO then
		return
	end

	local FormattedMessage = string.format(Message, ...)
	print(FormatMessage("INFO", ScriptName, FormattedMessage))
end

function Logger.Warning(ScriptName: string?, Message: string, ...: any)
	if not DebuggingEnabled then
		return
	end
	if CurrentLogLevel > LOG_LEVEL_WARNING then
		return
	end

	local FormattedMessage = string.format(Message, ...)
	warn(FormatMessage("WARN", ScriptName, FormattedMessage))
end

function Logger.Error(ScriptName: string?, Message: string, ...: any)
	if not DebuggingEnabled then
		return
	end
	if CurrentLogLevel > LOG_LEVEL_ERROR then
		return
	end

	local FormattedMessage = string.format(Message, ...)
	warn(FormatMessage("ERROR", ScriptName, FormattedMessage))
end

return Logger
