--!strict
local Formulas = {}

-- Clamps a value between a minimum and maximum range
function Formulas.Clamp(Value: number, Min: number, Max: number): number
	return math.max(Min, math.min(Max, Value))
end

-- Linearly interpolates between Start and End by Alpha
function Formulas.Lerp(Start: number, End: number, Alpha: number): number
	return Start + (End - Start) * Alpha
end

-- Calculates the 3D distance between two points
function Formulas.Distance(PointA: Vector3, PointB: Vector3): number
	return (PointA - PointB).Magnitude
end

-- Calculates the horizontal (XZ plane) distance between two points
function Formulas.DistanceXZ(PointA: Vector3, PointB: Vector3): number
	local FlatA = Vector3.new(PointA.X, 0, PointA.Z)
	local FlatB = Vector3.new(PointB.X, 0, PointB.Z)
	return (FlatA - FlatB).Magnitude
end

-- Rounds a value to the specified number of decimal places (default is 0)
function Formulas.Round(Value: number, DecimalPlaces: number?): number
	local Multiplier = 10 ^ (DecimalPlaces or 0)
	return math.floor(Value * Multiplier + 0.5) / Multiplier
end

-- Maps a value from one range to another
function Formulas.MapRange(Value: number, InMin: number, InMax: number, OutMin: number, OutMax: number): number
	return OutMin + (Value - InMin) * (OutMax - OutMin) / (InMax - InMin)
end

-- Calculates the average of a list of numbers
function Formulas.GetAverage(Values: {number}): number
	if #Values == 0 then
		return 0
	end

	local Sum = 0
	for _, Value in pairs(Values) do
		Sum += Value
	end

	return Sum / #Values
end

-- Converts degrees to radians
function Formulas.DegToRad(Degrees: number): number
	return Degrees * math.pi / 180
end

-- Converts radians to degrees
function Formulas.RadToDeg(Radians: number): number
	return Radians * 180 / math.pi
end

-- Returns the sign of a number (-1 if negative, 1 if positive, 0 if zero)
function Formulas.Sign(Value: number): number
	if Value > 0 then
		return 1
	elseif Value < 0 then
		return -1
	else
		return 0
	end
end

-- Returns true if a number is approximately equal to another within a tolerance
function Formulas.Approximately(Value1: number, Value2: number, Tolerance: number): boolean
	return math.abs(Value1 - Value2) <= (Tolerance or 0.0001)
end

-- Calculates the factorial of a non-negative integer
function Formulas.Factorial(N: number): number
	if N <= 1 then
		return 1
	end
	return N * Formulas.Factorial(N - 1)
end

-- Clamps a vector's magnitude to a maximum length
function Formulas.ClampMagnitude(Vector: Vector3, MaxLength: number): Vector3
	local Magnitude = Vector.Magnitude
	if Magnitude > MaxLength then
		return Vector.Unit * MaxLength
	else
		return Vector
	end
end

-- Returns the component-wise minimum of two vectors
function Formulas.VectorMin(A: Vector3, B: Vector3): Vector3
	return Vector3.new(
		math.min(A.X, B.X),
		math.min(A.Y, B.Y),
		math.min(A.Z, B.Z)
	)
end

-- Returns the component-wise maximum of two vectors
function Formulas.VectorMax(A: Vector3, B: Vector3): Vector3
	return Vector3.new(
		math.max(A.X, B.X),
		math.max(A.Y, B.Y),
		math.max(A.Z, B.Z)
	)
end

return Formulas