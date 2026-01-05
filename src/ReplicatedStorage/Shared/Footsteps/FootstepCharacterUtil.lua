--!strict

local FootstepCharacterUtil = {}

function FootstepCharacterUtil.GetHumanoidRootPart(Character: Model): BasePart?
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end
	return nil
end

function FootstepCharacterUtil.GetHumanoid(Character: Model): Humanoid?
	local HumanoidInstance = Character:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance then
		return HumanoidInstance
	end
	return nil
end

function FootstepCharacterUtil.GetSpeed(Character: Model): number
	local RootPart = FootstepCharacterUtil.GetHumanoidRootPart(Character)
	if not RootPart then
		return 0
	end
	return RootPart.AssemblyLinearVelocity.Magnitude
end

return FootstepCharacterUtil
