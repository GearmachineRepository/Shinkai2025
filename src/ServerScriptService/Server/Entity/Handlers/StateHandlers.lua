--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local StateHandlers = {}

function StateHandlers.Setup(Controller: any)
	local StateManager = Controller.StateManager
	local Character = Controller.Character
	local Maid = Controller.Maid

	Maid:GiveTask(StateManager:OnStateChanged(StateTypes.RAGDOLLED, function(IsRagdolled: boolean)
		if IsRagdolled then
			return
		end
	end))

	Maid:GiveTask(StateManager:OnStateChanged(StateTypes.STUNNED, function(IsStunned: boolean)
		if IsStunned then
			Controller.Humanoid.WalkSpeed = 0
			return
		end

		if Controller.GetExpectedWalkSpeed then
			local CurrentMode = Character:GetAttribute("MovementMode")
			Controller.Humanoid.WalkSpeed = Controller:GetExpectedWalkSpeed(CurrentMode)
			return
		end
	end))

	Maid:GiveTask(StateManager:OnStateChanged(StateTypes.ATTACKING, function(IsAttacking: boolean)
		if IsAttacking then
			return
		end
	end))

	Maid:GiveTask(StateManager:OnStateChanged(StateTypes.INVULNERABLE, function(IsInvulnerable: boolean)
		if IsInvulnerable then
			if not Character:FindFirstChildOfClass("ForceField") then
				local ForceField = Instance.new("ForceField")
				ForceField.Parent = Character
			end
			return
		end

		local ExistingForceField = Character:FindFirstChildOfClass("ForceField")
		if ExistingForceField then
			ExistingForceField:Destroy()
		end
	end))
end

return StateHandlers
