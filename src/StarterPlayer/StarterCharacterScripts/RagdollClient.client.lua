--!strict

local Character: Model = script.Parent

local Torso: BasePart = Character:WaitForChild("LowerTorso") :: BasePart
local Humanoid: Humanoid = Character:FindFirstChildWhichIsA("Humanoid")
	or Character:WaitForChild("Humanoid") :: Humanoid

local function PushCharacter()
	Torso:ApplyImpulse(Torso.CFrame.LookVector * -100)
end

Character:GetAttributeChangedSignal("Ragdoll"):Connect(function()
	local IsRagdoll = Character:GetAttribute("Ragdoll")

	if IsRagdoll then
		Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

		PushCharacter()
	else
		Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)
