--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)

local PositionHistoryComponent = {}
PositionHistoryComponent.__index = PositionHistoryComponent

PositionHistoryComponent.ComponentName = "PositionHistory"
PositionHistoryComponent.Dependencies = {}
PositionHistoryComponent.UpdateRate = 1 / 20

type PositionSample = {
	Timestamp: number,
	Position: Vector3,
	Rotation: CFrame,
}

local DEFAULT_HISTORY_DURATION = 0.5
local DEFAULT_MAX_SAMPLES = 15

function PositionHistoryComponent.new(Entity: Types.Entity, _Context: Types.EntityContext)
	local self = setmetatable({
		Entity = Entity,
		Maid = Ensemble.Maid.new(),
		Samples = {},
		MaxHistoryDuration = DEFAULT_HISTORY_DURATION,
		MaxSamples = DEFAULT_MAX_SAMPLES,
	}, PositionHistoryComponent) :: any

	return self
end

function PositionHistoryComponent.Update(self, _DeltaTime: number)
	local Character = self.Entity.Character
	if not Character then
		return
	end

	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return
	end

	local CurrentTime = workspace:GetServerTimeNow()

	local NewSample: PositionSample = {
		Timestamp = CurrentTime,
		Position = RootPart.Position,
		Rotation = RootPart.CFrame,
	}

	table.insert(self.Samples, NewSample)

	while #self.Samples > self.MaxSamples do
		table.remove(self.Samples, 1)
	end

	local CutoffTime = CurrentTime - self.MaxHistoryDuration
	while #self.Samples > 1 and self.Samples[1].Timestamp < CutoffTime do
		table.remove(self.Samples, 1)
	end
end

function PositionHistoryComponent.GetPositionAtTime(self, TargetTime: number): Vector3?
	if #self.Samples == 0 then
		return nil
	end

	if #self.Samples == 1 then
		return self.Samples[1].Position
	end

	if TargetTime <= self.Samples[1].Timestamp then
		return self.Samples[1].Position
	end

	if TargetTime >= self.Samples[#self.Samples].Timestamp then
		return self.Samples[#self.Samples].Position
	end

	local BeforeSample: PositionSample? = nil
	local AfterSample: PositionSample? = nil

	for Index = #self.Samples, 1, -1 do
		local Sample = self.Samples[Index]
		if Sample.Timestamp <= TargetTime then
			BeforeSample = Sample :: any
			if Index < #self.Samples then
				AfterSample = self.Samples[Index + 1] :: any
			end
			break
		end
	end

	if not BeforeSample then
		return self.Samples[1].Position
	end

	if not AfterSample then
		return BeforeSample.Position
	end

	local TimeDelta = AfterSample.Timestamp - BeforeSample.Timestamp
	if TimeDelta <= 0 then
		return BeforeSample.Position
	end

	local Alpha = (TargetTime - BeforeSample.Timestamp) / TimeDelta
	Alpha = math.clamp(Alpha, 0, 1)

	return BeforeSample.Position:Lerp(AfterSample.Position, Alpha)
end

function PositionHistoryComponent.GetRotationAtTime(self, TargetTime: number): CFrame?
	if #self.Samples == 0 then
		return nil
	end

	if #self.Samples == 1 then
		return self.Samples[1].Rotation
	end

	if TargetTime <= self.Samples[1].Timestamp then
		return self.Samples[1].Rotation
	end

	if TargetTime >= self.Samples[#self.Samples].Timestamp then
		return self.Samples[#self.Samples].Rotation
	end

	local BeforeSample: PositionSample? = nil
	local AfterSample: PositionSample? = nil

	for Index = #self.Samples, 1, -1 do
		local Sample = self.Samples[Index]
		if Sample.Timestamp <= TargetTime then
			BeforeSample = Sample :: any
			if Index < #self.Samples then
				AfterSample = self.Samples[Index + 1] :: any
			end
			break
		end
	end

	if not BeforeSample then
		return self.Samples[1].Rotation
	end

	if not AfterSample then
		return BeforeSample.Rotation
	end

	local TimeDelta = AfterSample.Timestamp - BeforeSample.Timestamp
	if TimeDelta <= 0 then
		return BeforeSample.Rotation
	end

	local Alpha = (TargetTime - BeforeSample.Timestamp) / TimeDelta
	Alpha = math.clamp(Alpha, 0, 1)

	return BeforeSample.Rotation:Lerp(AfterSample.Rotation, Alpha)
end

function PositionHistoryComponent.WasInHitbox(
	self,
	AttackerCFrame: CFrame,
	HitboxSize: Vector3,
	HitboxOffset: Vector3,
	RewindSeconds: number
): boolean
	local TargetTime = workspace:GetServerTimeNow() - RewindSeconds
	local HistoricalPosition = self:GetPositionAtTime(TargetTime)

	if not HistoricalPosition then
		return false
	end

	local _HitboxCenter = AttackerCFrame:PointToWorldSpace(HitboxOffset)
	local HalfSize = HitboxSize / 2

	local LocalOffset = AttackerCFrame:PointToObjectSpace(HistoricalPosition)

	return math.abs(LocalOffset.X) <= HalfSize.X
		and math.abs(LocalOffset.Y) <= HalfSize.Y
		and math.abs(LocalOffset.Z) <= HalfSize.Z
end

function PositionHistoryComponent.GetCurrentPosition(self): Vector3?
	if #self.Samples == 0 then
		return nil
	end
	return self.Samples[#self.Samples].Position
end

function PositionHistoryComponent.GetSampleCount(self): number
	return #self.Samples
end

function PositionHistoryComponent.ClearHistory(self)
	table.clear(self.Samples)
end

function PositionHistoryComponent.Destroy(self)
	self.Maid:DoCleaning()
	table.clear(self.Samples)
end

return PositionHistoryComponent