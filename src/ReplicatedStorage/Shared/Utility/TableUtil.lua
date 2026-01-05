--!strict

local TableUtil = {}

function TableUtil.DeepCopy(Original: {[any]: any}): {[any]: any}
	local Copy = {}

	for Key, Value in Original do
		if type(Value) == "table" then
			Copy[Key] = TableUtil.DeepCopy(Value)
		else
			Copy[Key] = Value
		end
	end

	return Copy
end

function TableUtil.Merge(Target: {[any]: any}, Source: {[any]: any}): {[any]: any}
	for Key, Value in Source do
		if type(Value) == "table" and type(Target[Key]) == "table" then
			Target[Key] = TableUtil.Merge(Target[Key], Value)
		else
			Target[Key] = Value
		end
	end

	return Target
end

function TableUtil.Count(Table: {[any]: any}): number
	local Count = 0
	for _ in Table do
		Count += 1
	end
	return Count
end

function TableUtil.Map(Table: {any}, Mapper: (Value: any, Index: number) -> any): {any}
	local Result = {}
	for Index, Value in Table do
		Result[Index] = Mapper(Value, Index)
	end
	return Result
end

function TableUtil.Filter(Table: {any}, Predicate: (Value: any, Index: number) -> boolean): {any}
	local Result = {}
	for Index, Value in Table do
		if Predicate(Value, Index) then
			table.insert(Result, Value)
		end
	end
	return Result
end

return TableUtil