--!strict

local AttackFlags = {}

AttackFlags.GUARD_BREAK = "GuardBreak"
AttackFlags.UNBLOCKABLE = "Unblockable"
AttackFlags.UNPARRYABLE = "Unparryable"
AttackFlags.HEAVY = "Heavy"
AttackFlags.LAUNCHER = "Launcher"
AttackFlags.SWEEP = "Sweep"

function AttackFlags.HasFlag(Flags: { string }?, Flag: string): boolean
	if not Flags then
		return false
	end

	for _, CurrentFlag in Flags do
		if CurrentFlag == Flag then
			return true
		end
	end

	return false
end

function AttackFlags.HasAnyFlag(Flags: { string }?, FlagsToCheck: { string }): boolean
	if not Flags then
		return false
	end

	for _, Flag in FlagsToCheck do
		if AttackFlags.HasFlag(Flags, Flag) then
			return true
		end
	end

	return false
end

function AttackFlags.GetFlags(Metadata: { [string]: any }?): { string }?
	if not Metadata then
		return nil
	end

	local Flags = Metadata.Flags
	local Flag = Metadata.Flag

	if Flags and type(Flags) == "table" then
		return Flags
	end

	if Flag and type(Flag) == "string" then
		return { Flag }
	end

	return nil
end

return AttackFlags