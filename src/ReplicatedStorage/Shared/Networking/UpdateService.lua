--!strict

local RunService = game:GetService("RunService")

local UpdateService = {}

export type Callback = (DeltaTime: number) -> ()
export type Handle = number

type Entry = {
	Callback: Callback,
	RateSeconds: number,
	Accumulator: number,
}

local Entries: { [Handle]: Entry } = {}
local NextHandle: Handle = 1
local HeartbeatConnection: RBXScriptConnection? = nil

local function EnsureRunning()
	if HeartbeatConnection then
		return
	end

	HeartbeatConnection = RunService.Heartbeat:Connect(function(DeltaTime: number)
		for _, EntryValue in Entries do
			if EntryValue.RateSeconds <= 0 then
				EntryValue.Callback(DeltaTime)
				continue
			end

			EntryValue.Accumulator += DeltaTime
			if EntryValue.Accumulator < EntryValue.RateSeconds then
				continue
			end

			local Steps = math.floor(EntryValue.Accumulator / EntryValue.RateSeconds)
			EntryValue.Accumulator -= Steps * EntryValue.RateSeconds

			EntryValue.Callback(EntryValue.RateSeconds * Steps)
		end
	end)
end

local function TryStop()
	if next(Entries) ~= nil then
		return
	end

	if HeartbeatConnection then
		HeartbeatConnection:Disconnect()
		HeartbeatConnection = nil
	end
end

function UpdateService.Register(Callback: Callback, RateSeconds: number?): Handle
	local Handle = NextHandle
	NextHandle += 1

	Entries[Handle] = {
		Callback = Callback,
		RateSeconds = RateSeconds or 0,
		Accumulator = 0,
	}

	EnsureRunning()
	return Handle
end

function UpdateService.Disconnect(Handle: Handle)
	if Entries[Handle] then
		Entries[Handle] = nil
		TryStop()
	end
end

function UpdateService.RegisterWithCleanup(Callback: Callback, RateSeconds: number?): () -> ()
	local Handle = UpdateService.Register(Callback, RateSeconds)

	return function()
		UpdateService.Disconnect(Handle)
	end
end

return UpdateService
