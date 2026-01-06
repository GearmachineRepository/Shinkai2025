--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local FootstepConstants = require(Shared.Footsteps.FootstepConstants)
local FootstepMaterialMap = require(Shared.Footsteps.FootstepMaterialMap)
local FootstepCharacterUtil = require(Shared.Footsteps.FootstepCharacterUtil)

export type MaterialId = number

local FootstepMaterialQueries = {}

function FootstepMaterialQueries.GetFloorMaterial(Character: Model): Enum.Material
	local RootPart = FootstepCharacterUtil.GetHumanoidRootPart(Character)
	local HumanoidInstance = FootstepCharacterUtil.GetHumanoid(Character)

	if not RootPart or not HumanoidInstance then
		return Enum.Material.Air
	end

	local RaycastParamsInstance = RaycastParams.new()
	RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParamsInstance.FilterDescendantsInstances = { Character }

	local RayOrigin = RootPart.Position
	local RayDirection = Vector3.new(0, -FootstepConstants.RAY_DISTANCE_DOWN, 0)

	local Result = workspace:Raycast(RayOrigin, RayDirection, RaycastParamsInstance)
	if Result then
		return Result.Material
	end

	if HumanoidInstance.FloorMaterial ~= Enum.Material.Air then
		return HumanoidInstance.FloorMaterial
	end

	return Enum.Material.Air
end

function FootstepMaterialQueries.GetMaterialId(Character: Model): MaterialId?
	local FloorMaterial = FootstepMaterialQueries.GetFloorMaterial(Character)
	if FloorMaterial == Enum.Material.Air then
		return nil
	end

	return FootstepMaterialMap.GetId(FloorMaterial.Name)
end

function FootstepMaterialQueries.GetMaterialIdAtPosition(Character: Model, Position: Vector3): MaterialId?
	local RaycastParamsInstance = RaycastParams.new()
	RaycastParamsInstance.FilterType = Enum.RaycastFilterType.Exclude
	RaycastParamsInstance.FilterDescendantsInstances = { Character }

	local RayOrigin = Position + Vector3.new(0, FootstepConstants.POSITION_RAY_START_OFFSET, 0)
	local RayDirection = Vector3.new(0, -FootstepConstants.POSITION_RAY_DISTANCE_DOWN, 0)

	local Result = workspace:Raycast(RayOrigin, RayDirection, RaycastParamsInstance)
	if Result then
		return FootstepMaterialMap.GetId(Result.Material.Name)
	end

	return FootstepMaterialQueries.GetMaterialId(Character)
end

return FootstepMaterialQueries
