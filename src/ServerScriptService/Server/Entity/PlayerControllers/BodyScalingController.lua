--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StatTypes = require(Shared.Configurations.Enums.StatTypes)

local BodyScalingController = {}
BodyScalingController.__index = BodyScalingController

export type BodyScalingController = typeof(setmetatable({} :: {
	Controller: any,
	Humanoid: Humanoid,
	BaseDepth: number,
	BaseWidth: number,
}, BodyScalingController))

local MIN_SCALE = 1.0
local MAX_SCALE = 1.30
local MUSCLE_SCALE_MULTIPLIER = 0.0005
local FAT_SCALE_MULTIPLIER = 0.00035

function BodyScalingController.new(CharacterController: any): BodyScalingController
	local Humanoid = CharacterController.Humanoid

	local self = setmetatable({
		Controller = CharacterController,
		Humanoid = Humanoid,
		BaseDepth = Humanoid.BodyDepthScale.Value,
		BaseWidth = Humanoid.BodyWidthScale.Value,
	}, BodyScalingController)

	self:UpdateBodyScale()

	return self
end

function BodyScalingController:UpdateBodyScale()
	local MuscleStars = self.Controller.StatManager:GetStat(StatTypes.MUSCLE .. "_Stars") or 0
	local MuscleValue = MuscleStars * 12
	local Fat = self.Controller.StatManager:GetStat(StatTypes.FAT)

	local MuscleScale = MuscleValue * MUSCLE_SCALE_MULTIPLIER
	local FatScale = Fat * FAT_SCALE_MULTIPLIER

	local TotalDepthScale = math.clamp(self.BaseDepth + MuscleScale + FatScale, MIN_SCALE, MAX_SCALE)
	local TotalWidthScale = math.clamp(self.BaseWidth + MuscleScale + FatScale, MIN_SCALE, MAX_SCALE)

	self.Humanoid.BodyDepthScale.Value = TotalDepthScale
	self.Humanoid.BodyWidthScale.Value = TotalWidthScale
end

function BodyScalingController:Destroy()
end

return BodyScalingController