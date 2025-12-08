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
	_Tasks: { [any]: CleanupTask },
	GiveTask: (self: MaidSelf, Task: CleanupTask) -> CleanupTask,
	Set: (self: MaidSelf, Name: string, Task: CleanupTask) -> (),
	_cleanupItem: (self: MaidSelf, Task: CleanupTask) -> (),
	DoCleaning: (self: MaidSelf) -> (),
}

local Maid = {}
Maid.__index = Maid

function Maid.new(): MaidSelf
	local self = setmetatable({
		_Tasks = {},
	}, Maid)
	return self :: any
end

function Maid:GiveTask(Task: CleanupTask): CleanupTask
	table.insert(self._Tasks, Task)
	return Task
end

function Maid:Set(Name: string, Task: CleanupTask)
	local Old = self._Tasks[Name]
	if Old then
		self:_cleanupItem(Old)
	end
	self._Tasks[Name] = Task
end

function Maid:_cleanupItem(Task: CleanupTask)
	local TaskType = typeof(Task)

	if TaskType == "function" then
		(Task :: () -> ())()
	elseif TaskType == "RBXScriptConnection" then
		if (Task :: RBXScriptConnection).Connected then
			(Task :: RBXScriptConnection):Disconnect()
		end
	elseif TaskType == "Instance" then
		(Task :: Instance):Destroy()
	elseif TaskType == "table" then
		if typeof((Task :: any).Destroy) == "function" then
			(Task :: Destroyable):Destroy()
		elseif typeof((Task :: any).Disconnect) == "function" then
			(Task :: Disconnectable):Disconnect()
		elseif typeof((Task :: any).cancel) == "function" and typeof((Task :: any).getStatus) == "function" then
			if (Task :: PromiseLike):getStatus() == "Started" then
				(Task :: PromiseLike):cancel()
			end
		end
	end
end

function Maid:DoCleaning()
	for Key, Task in self._Tasks do
		self:_cleanupItem(Task)
		self._Tasks[Key] = nil
	end
end

return Maid