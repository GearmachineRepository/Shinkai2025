--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local BodyScalingBalance = require(Shared.Configurations.Balance.BodyScalingBalance)

export type BodyScalingComponent = {
	Entity: any,
	UpdateBodyScale: (self: BodyScalingComponent) -> (),
	Destroy: (self: BodyScalingComponent) -> (),
}

type BodyScalingComponentInternal = BodyScalingComponent & {
	Humanoid: Humanoid,
	BaseDepth: number,
	BaseWidth: number,
}

local BodyScalingComponent = {}
BodyScalingComponent.__index = BodyScalingComponent

function BodyScalingComponent.new(Entity: any): BodyScalingComponent
	local Humanoid = Entity.Humanoid

	local self: BodyScalingComponentInternal = setmetatable({
		Entity = Entity,
		Humanoid = Humanoid,
		BaseDepth = Humanoid.BodyDepthScale.Value,
		BaseWidth = Humanoid.BodyWidthScale.Value,
	}, BodyScalingComponent) :: any

	self:UpdateBodyScale()

	return self
end

function BodyScalingComponent:UpdateBodyScale()
	local MuscleStars = self.Entity.Stats:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
	local MuscleValue = MuscleStars * 12
	local Fat = self.Entity.Stats:GetStat(StatTypes.FAT)

	local MuscleScale = MuscleValue * BodyScalingBalance.Multipliers.MUSCLE_SCALE
	local FatScale = Fat * BodyScalingBalance.Multipliers.FAT_SCALE

	local TotalDepthScale =
		math.clamp(self.BaseDepth + MuscleScale + FatScale, BodyScalingBalance.Scale.MIN, BodyScalingBalance.Scale.MAX)
	local TotalWidthScale =
		math.clamp(self.BaseWidth + MuscleScale + FatScale, BodyScalingBalance.Scale.MIN, BodyScalingBalance.Scale.MAX)

	self.Humanoid.BodyDepthScale.Value = TotalDepthScale
	self.Humanoid.BodyWidthScale.Value = TotalWidthScale
end

function BodyScalingComponent:Destroy() end

return BodyScalingComponent
