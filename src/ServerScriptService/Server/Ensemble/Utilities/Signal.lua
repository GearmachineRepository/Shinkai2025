--!strict

local Types = require(script.Parent.Parent.Types)

type Connection = Types.Connection

type ConnectionInternal = Connection & {
	Callback: ((...any) -> ())?,
	Signal: SignalInternal?,
}

type SignalInternal = {
	Connections: { ConnectionInternal },
	YieldedThreads: { thread },
}

local Signal = {}
Signal.__index = Signal

local Connection = {}
Connection.__index = Connection

local function CreateConnection(SignalInstance: SignalInternal, Callback: (...any) -> ()): ConnectionInternal
	local self: ConnectionInternal = setmetatable({
		Connected = true,
		Callback = Callback,
		Signal = SignalInstance,
	}, Connection) :: any

	return self
end

function Connection.Disconnect(self: ConnectionInternal)
	if not self.Connected then
		return
	end

	self.Connected = false

	local SignalInstance = self.Signal
	if not SignalInstance then
		return
	end

	local Connections = SignalInstance.Connections
	local Index = table.find(Connections, self)
	if Index then
		local LastIndex = #Connections
		Connections[Index] = Connections[LastIndex]
		Connections[LastIndex] = nil
	end

	self.Callback = nil
	self.Signal = nil
end

function Signal.new<T...>(): Types.Signal<T...>
	local self: SignalInternal = setmetatable({
		Connections = {},
		YieldedThreads = {},
	}, Signal) :: any

	return self :: any
end

function Signal.Is(Value: any): boolean
	return type(Value) == "table" and getmetatable(Value) == Signal
end

function Signal:Connect(Callback: (...any) -> ()): Connection
	local NewConnection = CreateConnection(self, Callback)
	table.insert(self.Connections, NewConnection)
	return NewConnection
end

function Signal:Once(Callback: (...any) -> ()): Connection
	local OnceConnection: ConnectionInternal

	OnceConnection = CreateConnection(self, function(...)
		if OnceConnection.Connected then
			OnceConnection:Disconnect()
			Callback(...)
		end
	end)

	table.insert(self.Connections, OnceConnection)
	return OnceConnection
end

function Signal:Fire(...: any)
	for Index = #self.Connections, 1, -1 do
		local ConnectionEntry = self.Connections[Index]
		if ConnectionEntry.Connected and ConnectionEntry.Callback then
			task.spawn(ConnectionEntry.Callback, ...)
		end
	end

	for Index = #self.YieldedThreads, 1, -1 do
		local YieldedThread = self.YieldedThreads[Index]
		self.YieldedThreads[Index] = nil
		task.spawn(YieldedThread, ...)
	end
end

function Signal:Wait(): ...any
	table.insert(self.YieldedThreads, coroutine.running())
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for Index = #self.Connections, 1, -1 do
		local ConnectionEntry = self.Connections[Index]
		ConnectionEntry.Connected = false
		ConnectionEntry.Callback = nil
		ConnectionEntry.Signal = nil
	end

	table.clear(self.Connections)

	for Index = #self.YieldedThreads, 1, -1 do
		local YieldedThread = self.YieldedThreads[Index]
		task.cancel(YieldedThread)
	end

	table.clear(self.YieldedThreads)
end

function Signal:Destroy()
	self:DisconnectAll()
end

return Signal