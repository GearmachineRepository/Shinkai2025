--!strict

export type Callback = (...any) -> ()

export type CallbackEntry = {
	Callback: Callback,
	ScopeKey: any?,
}

export type CallbackConnection = {
	Disconnect: () -> (),
	Connected: boolean,
}

local CallbackRegistry = {}

local Callbacks: { [string]: { CallbackEntry } } = {}
local CallbackCounts: { [string]: number } = {}

local IMMEDIATE_FIRE_PATTERNS = {
	"^Event:",
	"^StateChanged:",
	"Attack",
	"Damage",
	"Speed",
	"StaminaCost",
}

local function ShouldFireImmediately(CallbackKey: string): boolean
	for _, Pattern in IMMEDIATE_FIRE_PATTERNS do
		if string.find(CallbackKey, Pattern) then
			return true
		end
	end
	return false
end

function CallbackRegistry.Register(CallbackKey: string, Callback: Callback, ScopeKey: any?): CallbackConnection
	if not Callbacks[CallbackKey] then
		Callbacks[CallbackKey] = {}
		CallbackCounts[CallbackKey] = 0
	end

	local Entry: CallbackEntry = {
		Callback = Callback,
		ScopeKey = ScopeKey,
	}

	table.insert(Callbacks[CallbackKey], Entry)
	CallbackCounts[CallbackKey] += 1

	local Connection = {
		Connected = true,
		Disconnect = nil :: any,
	}

	function Connection.Disconnect()
		if not Connection.Connected then
			return
		end

		Connection.Connected = false

		local CallbackList = Callbacks[CallbackKey]
		if not CallbackList then
			return
		end

		local Index = table.find(CallbackList, Entry)
		if Index then
			table.remove(CallbackList, Index)
			CallbackCounts[CallbackKey] -= 1
		end
	end

	return Connection
end

function CallbackRegistry.Fire(CallbackKey: string, ...: any)
	local CallbackList = Callbacks[CallbackKey]
	if not CallbackList or #CallbackList == 0 then
		return
	end

	if ShouldFireImmediately(CallbackKey) then
		for _, Entry in CallbackList do
			Entry.Callback(...)
		end
	else
		for _, Entry in CallbackList do
			task.defer(Entry.Callback, ...)
		end
	end
end

function CallbackRegistry.ClearScope(ScopeKey: any)
	if not ScopeKey then
		return
	end

	for CallbackKey, CallbackList in Callbacks do
		for Index = #CallbackList, 1, -1 do
			local Entry = CallbackList[Index]
			if Entry.ScopeKey == ScopeKey then
				table.remove(CallbackList, Index)
				CallbackCounts[CallbackKey] -= 1
			end
		end
	end
end

function CallbackRegistry.Clear(CallbackKey: string?)
	if CallbackKey then
		Callbacks[CallbackKey] = nil
		CallbackCounts[CallbackKey] = 0
	else
		table.clear(Callbacks)
		table.clear(CallbackCounts)
	end
end

function CallbackRegistry.GetCount(CallbackKey: string): number
	return CallbackCounts[CallbackKey] or 0
end

function CallbackRegistry.GetAllCounts(): { [string]: number }
	return table.clone(CallbackCounts)
end

function CallbackRegistry.DebugPrint()
	for Key, Count in CallbackCounts do
		if Count > 0 then
			print(string.format("  %s: %d callbacks", Key, Count))
		end
	end
end

return CallbackRegistry
