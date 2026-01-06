--!strict

local CombatTypes = require(script.Parent.Parent.CombatTypes)

type ActionContext = CombatTypes.ActionContext

local ThreadScheduler = {}

function ThreadScheduler.Schedule(Context: ActionContext, Duration: number, Callback: () -> (), IgnoreInterrupt: boolean?): thread
	Context.PendingThreads = Context.PendingThreads or {}

	local NewThread = task.delay(Duration, function()
		if Context.PendingThreads then
			local ThreadList = Context.PendingThreads
			for Index, StoredThread in ThreadList do
				if StoredThread == coroutine.running() then
					table.remove(ThreadList, Index)
					break
				end
			end
		end

		if not IgnoreInterrupt and Context.Interrupted then
			return
		end

		Callback()
	end)

	table.insert(Context.PendingThreads :: { thread }, NewThread)
	return NewThread
end

function ThreadScheduler.CancelAll(Context: ActionContext)
	if not Context.PendingThreads then
		return
	end

	for _, Thread in Context.PendingThreads do
		local Status = coroutine.status(Thread)
		if Status == "suspended" then
			task.cancel(Thread)
		end
	end

	table.clear(Context.PendingThreads)
end

function ThreadScheduler.CancelThread(Context: ActionContext, TargetThread: thread)
	if not Context.PendingThreads then
		return
	end

	for Index, Thread in Context.PendingThreads do
		if Thread == TargetThread then
			local Status = coroutine.status(Thread)
			if Status == "suspended" then
				task.cancel(Thread)
			end
			table.remove(Context.PendingThreads, Index)
			return
		end
	end
end

function ThreadScheduler.GetPendingCount(Context: ActionContext): number
	if not Context.PendingThreads then
		return 0
	end

	return #Context.PendingThreads
end

return ThreadScheduler