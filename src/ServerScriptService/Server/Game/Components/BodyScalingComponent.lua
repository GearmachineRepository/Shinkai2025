--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Types = require(Server.Ensemble.Types)

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local BodyScalingBalance = require(Shared.Configurations.Balance.BodyScalingBalance)

local BodyScalingComponent = {}
BodyScalingComponent.__index = BodyScalingComponent

BodyScalingComponent.ComponentName = "BodyScaling"
BodyScalingComponent.Dependencies = { "Stats" }

type Self = {
	Entity: Types.Entity,
	Humanoid: Humanoid,
	BaseDepth: number,
	BaseWidth: number,
}

function BodyScalingComponent.new(Entity: Types.Entity, _Context: Types.EntityContext): Self
	local self: Self = setmetatable({
		Entity = Entity,
		Humanoid = Entity.Humanoid,
		BaseDepth = 1,
		BaseWidth = 1,
	}, BodyScalingComponent) :: any

	BodyScalingComponent.UpdateBodyScale(self)

	return self
end

function BodyScalingComponent.UpdateBodyScale(self: Self)
	local MuscleStars = self.Entity.Stats:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
	local MuscleValue = MuscleStars * 12
	local Fat = self.Entity.Stats:GetStat(StatTypes.FAT)

	local MuscleScale = MuscleValue * BodyScalingBalance.Multipliers.MUSCLE_SCALE
	local FatScale = Fat * BodyScalingBalance.Multipliers.FAT_SCALE

	local TotalDepthScale =
		math.clamp(self.BaseDepth + MuscleScale + FatScale, BodyScalingBalance.Scale.MIN, BodyScalingBalance.Scale.MAX)
	local TotalWidthScale =
		math.clamp(self.BaseWidth + MuscleScale + FatScale, BodyScalingBalance.Scale.MIN, BodyScalingBalance.Scale.MAX)

	local BodyDepthScale = self.Humanoid:FindFirstChild("BodyDepthScale") :: NumberValue
	local BodyWidthScale = self.Humanoid:FindFirstChild("BodyWidthScale") :: NumberValue
	if not BodyDepthScale or not BodyWidthScale then
		return
	end
	BodyDepthScale.Value = TotalDepthScale
	BodyWidthScale.Value = TotalWidthScale
end

function BodyScalingComponent.Destroy(_self: Self) end

return BodyScalingComponent