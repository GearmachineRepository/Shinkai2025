--!strict

--[[
  ____  ___  ___ _      _______
 / __ \/ _ \/ _ | | /| / / ___/
/ /_/ / // / __ | |/ |/ / (_ /
\____/____/_/ |_|__/|__/\___/
]]

export type Destroyable = { Destroy: (self: any) -> () }
export type Disconnectable = { Disconnect: (self: any) -> () }
export type PromiseLike = { cancel: (self: any) -> (), getStatus: (self: any) -> string }
export type CleanupTask = RBXScriptConnection | Instance | (() -> ()) | Destroyable | Disconnectable | PromiseLike

export type MaidSelf = {
	Tasks: { [any]: CleanupTask },
	GiveTask: (self: MaidSelf, Task: CleanupTask) -> CleanupTask,
	Set: (self: MaidSelf, Name: string, Task: CleanupTask?) -> (),
	CleanupItem: (self: MaidSelf, Task: CleanupTask) -> (),
	DoCleaning: (self: MaidSelf) -> (),
}

local Maid = {}
Maid.__index = Maid

function Maid.new(): MaidSelf
	return setmetatable({
		Tasks = {},
	}, Maid) :: any
end

function Maid:GiveTask(Task: CleanupTask): CleanupTask
	table.insert(self.Tasks, Task)
	return Task
end

function Maid:Set(Name: string, Task: CleanupTask?)
	local Tasks = self.Tasks
	local OldTask = Tasks[Name]
	if OldTask then
		self:CleanupItem(OldTask)
	end
	Tasks[Name] = Task
end

function Maid:CleanupItem(Task: CleanupTask)
	local TaskType = typeof(Task)

	if TaskType == "function" then
		(Task :: () -> ())()
		return
	end

	if TaskType == "RBXScriptConnection" then
		local Connection = Task :: RBXScriptConnection
		if Connection.Connected then
			Connection:Disconnect()
		end
		return
	end

	if TaskType == "Instance" then
		(Task :: Instance):Destroy()
		return
	end

	if TaskType ~= "table" then
		return
	end

	local AnyTask = Task :: any

	local DestroyUnknown = AnyTask.Destroy :: any
	if type(DestroyUnknown) == "function" then
		(DestroyUnknown :: (any) -> ())(AnyTask)
		return
	end

	local DisconnectUnknown = AnyTask.Disconnect :: any
	if type(DisconnectUnknown) == "function" then
		(DisconnectUnknown :: (any) -> ())(AnyTask)
		return
	end

	local CancelUnknown = AnyTask.cancel :: any
	local GetStatusUnknown = AnyTask.getStatus :: any
	if type(CancelUnknown) == "function" and type(GetStatusUnknown) == "function" then
		local GetStatus = GetStatusUnknown :: (any) -> string
		if GetStatus(AnyTask) == "Started" then
			local Cancel = CancelUnknown :: (any) -> ()
			Cancel(AnyTask)
		end
	end
end

function Maid:DoCleaning()
	local Tasks = self.Tasks :: { [any]: CleanupTask }

	local Key, Value = next(Tasks)
	while Value ~= nil do
		Tasks[Key] = nil
		self:CleanupItem(Value :: CleanupTask)
		Key, Value = next(Tasks)
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid
