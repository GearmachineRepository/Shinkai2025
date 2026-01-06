--!strict

local LatencyCompensation = {}

LatencyCompensation.MAX_COMPENSATION_SECONDS = 0.15
LatencyCompensation.MAX_VALID_INPUT_AGE_SECONDS = 0.3

function LatencyCompensation.GetCompensation(InputTimestamp: number?): number
	if not InputTimestamp then
		return 0
	end

	local ServerNow = workspace:GetServerTimeNow()
	local InputAge = ServerNow - InputTimestamp

	if InputAge < 0 then
		return 0
	end

	if InputAge > LatencyCompensation.MAX_VALID_INPUT_AGE_SECONDS then
		return 0
	end

	return math.min(InputAge, LatencyCompensation.MAX_COMPENSATION_SECONDS)
end

return LatencyCompensation