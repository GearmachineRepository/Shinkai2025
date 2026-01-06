--!strict

local Formulas = {}

function Formulas.Clamp(Value: number, Min: number, Max: number): number
	return math.max(Min, math.min(Max, Value))
end

function Formulas.Lerp(Start: number, End: number, Alpha: number): number
	return Start + (End - Start) * Alpha
end

function Formulas.InverseLerp(Start: number, End: number, Value: number): number
	if Start == End then
		return 0
	end
	return (Value - Start) / (End - Start)
end

function Formulas.Remap(Value: number, InMin: number, InMax: number, OutMin: number, OutMax: number): number
	local Alpha = Formulas.InverseLerp(InMin, InMax, Value)
	return Formulas.Lerp(OutMin, OutMax, Alpha)
end

function Formulas.Round(Value: number, DecimalPlaces: number?): number
	local Multiplier = 10 ^ (DecimalPlaces or 0)
	return math.floor(Value * Multiplier + 0.5) / Multiplier
end

function Formulas.Distance(PointA: Vector3, PointB: Vector3): number
	return (PointA - PointB).Magnitude
end

function Formulas.DistanceXZ(PointA: Vector3, PointB: Vector3): number
	local FlatA = Vector3.new(PointA.X, 0, PointA.Z)
	local FlatB = Vector3.new(PointB.X, 0, PointB.Z)
	return (FlatA - FlatB).Magnitude
end

function Formulas.Percentage(Value: number, Total: number): number
	if Total == 0 then
		return 0
	end
	return (Value / Total) * 100
end

function Formulas.FromPercentage(Percent: number, Total: number): number
	return (Percent / 100) * Total
end

function Formulas.SafeDivide(Numerator: number, Denominator: number): number
	if Denominator == 0 then
		return 0
	end
	return Numerator / Denominator
end

function Formulas.IsNearlyEqual(ValueA: number, ValueB: number, Epsilon: number?): boolean
	return math.abs(ValueA - ValueB) < (Epsilon or 0.0001)
end

function Formulas.IsWithinThreshold(Value: number, Target: number, Threshold: number): boolean
	return math.abs(Value - Target) <= Threshold
end

function Formulas.ExponentialDecay(Current: number, Target: number, Rate: number, DeltaTime: number): number
	return Current + (Target - Current) * (1 - math.exp(-Rate * DeltaTime))
end

function Formulas.Sign(Value: number): number
	if Value > 0 then
		return 1
	elseif Value < 0 then
		return -1
	end
	return 0
end

function Formulas.ClampMagnitude(Vector: Vector3, MaxLength: number): Vector3
	local Magnitude = Vector.Magnitude
	if Magnitude > MaxLength then
		return Vector.Unit * MaxLength
	end
	return Vector
end

function Formulas.VectorMin(VectorA: Vector3, VectorB: Vector3): Vector3
	return Vector3.new(
		math.min(VectorA.X, VectorB.X),
		math.min(VectorA.Y, VectorB.Y),
		math.min(VectorA.Z, VectorB.Z)
	)
end

function Formulas.VectorMax(VectorA: Vector3, VectorB: Vector3): Vector3
	return Vector3.new(
		math.max(VectorA.X, VectorB.X),
		math.max(VectorA.Y, VectorB.Y),
		math.max(VectorA.Z, VectorB.Z)
	)
end

function Formulas.DegToRad(Degrees: number): number
	return math.rad(Degrees)
end

function Formulas.RadToDeg(Radians: number): number
	return math.deg(Radians)
end

function Formulas.GetAverage(Values: { number }): number
	if #Values == 0 then
		return 0
	end
	local Sum = 0
	for _, Value in Values do
		Sum += Value
	end
	return Sum / #Values
end

return Formulas