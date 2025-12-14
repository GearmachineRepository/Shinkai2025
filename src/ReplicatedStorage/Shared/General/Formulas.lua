--!strict
local Formulas = {}

function Formulas.Clamp(Value: number, Min: number, Max: number): number
	return math.max(Min, math.min(Max, Value))
end

function Formulas.Lerp(Start: number, End: number, Alpha: number): number
	return Start + (End - Start) * Alpha
end

function Formulas.Distance(PointA: Vector3, PointB: Vector3): number
	return (PointA - PointB).Magnitude
end

function Formulas.DistanceXZ(PointA: Vector3, PointB: Vector3): number
	local FlatA = Vector3.new(PointA.X, 0, PointA.Z)
	local FlatB = Vector3.new(PointB.X, 0, PointB.Z)
	return (FlatA - FlatB).Magnitude
end

function Formulas.Round(Value: number, DecimalPlaces: number?): number
	local Multiplier = 10 ^ (DecimalPlaces or 0)
	return math.floor(Value * Multiplier + 0.5) / Multiplier
end

function Formulas.MapRange(Value: number, InMin: number, InMax: number, OutMin: number, OutMax: number): number
	return OutMin + (Value - InMin) * (OutMax - OutMin) / (InMax - InMin)
end

function Formulas.GetAverage(Values: { number }): number
	if #Values == 0 then
		return 0
	end

	local Sum = 0
	for _, Value in pairs(Values) do
		Sum += Value
	end

	return Sum / #Values
end

function Formulas.DegToRad(Degrees: number): number
	return Degrees * math.pi / 180
end

function Formulas.RadToDeg(Radians: number): number
	return Radians * 180 / math.pi
end

function Formulas.Sign(Value: number): number
	if Value > 0 then
		return 1
	elseif Value < 0 then
		return -1
	else
		return 0
	end
end

function Formulas.Approximately(Value1: number, Value2: number, Tolerance: number): boolean
	return math.abs(Value1 - Value2) <= (Tolerance or 0.0001)
end

function Formulas.Factorial(N: number): number
	if N <= 1 then
		return 1
	end
	return N * Formulas.Factorial(N - 1)
end

function Formulas.ClampMagnitude(Vector: Vector3, MaxLength: number): Vector3
	local Magnitude = Vector.Magnitude
	if Magnitude > MaxLength then
		return Vector.Unit * MaxLength
	else
		return Vector
	end
end

function Formulas.VectorMin(A: Vector3, B: Vector3): Vector3
	return Vector3.new(math.min(A.X, B.X), math.min(A.Y, B.Y), math.min(A.Z, B.Z))
end

function Formulas.VectorMax(A: Vector3, B: Vector3): Vector3
	return Vector3.new(math.max(A.X, B.X), math.max(A.Y, B.Y), math.max(A.Z, B.Z))
end

function Formulas.Percentage(Value: number, Total: number): number
	if Total == 0 then
		return 0
	end
	return (Value / Total) * 100
end

function Formulas.IsWithinThreshold(Value: number, Target: number, Threshold: number): boolean
	return math.abs(Value - Target) <= Threshold
end

function Formulas.FromPercentage(Percentage: number, Total: number): number
	return (Percentage / 100) * Total
end

function Formulas.ExponentialDecay(Current: number, Target: number, Rate: number, DeltaTime: number): number
	return Current + (Target - Current) * (1 - math.exp(-Rate * DeltaTime))
end

function Formulas.SafeDivide(Numerator: number, Denominator: number): number
	if Denominator == 0 then
		return 0
	end
	return Numerator / Denominator
end

function Formulas.IsNearlyEqual(Value1: number, Value2: number, Epsilon: number?): boolean
	local Eps = Epsilon or 0.01
	return math.abs(Value1 - Value2) < Eps
end

return Formulas
