--!strict

local Types = require(script.Parent.Parent.Types)

type CleanupTask = Types.CleanupTask

type MaidInternal = Types.Maid & {
	Tasks: { [any]: CleanupTask },
}

local Maid = {}
Maid.__index = Maid

function Maid.new(): Types.Maid
	local self: MaidInternal = setmetatable({
		Tasks = {},
	}, Maid) :: any

	return self
end

function Maid.IsMaid(Value: any): boolean
	return type(Value) == "table" and getmetatable(Value) == Maid
end

function Maid:GiveTask(Task: CleanupTask): CleanupTask
	table.insert(self.Tasks, Task)
	return Task
end

local function CleanupItem(Task: CleanupTask)
	local TaskType = typeof(Task)

	if TaskType == "function" then
		(Task :: () -> ())()
		return
	end

	if TaskType == "RBXScriptConnection" then
		local TaskConnection = Task :: RBXScriptConnection
		if TaskConnection.Connected then
			TaskConnection:Disconnect()
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

	local TableTask = Task :: any

	if type(TableTask.Destroy) == "function" then
		TableTask:Destroy()
		return
	end

	if type(TableTask.Disconnect) == "function" then
		TableTask:Disconnect()
		return
	end

	if type(TableTask.cancel) == "function" and type(TableTask.getStatus) == "function" then
		if TableTask:getStatus() == "Started" then
			TableTask:cancel()
		end
	end
end

function Maid:Set(Name: string, Task: CleanupTask?)
	local OldTask = self.Tasks[Name]
	if OldTask then
		CleanupItem(OldTask)
	end
	self.Tasks[Name] = Task :: CleanupTask
end

function Maid:DoCleaning()
	local Tasks = self.Tasks :: { [any]: CleanupTask }

	local Key, Value = next(Tasks)
	while Value ~= nil do
		Tasks[Key] = nil
		CleanupItem(Value)
		Key, Value = next(Tasks)
	end
end

Maid.Destroy = Maid.DoCleaning

return Maid