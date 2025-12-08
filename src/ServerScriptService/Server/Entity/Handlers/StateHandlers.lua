--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local StateTypes = require(Shared.Configurations.Enums.StateTypes)

local StateHandlers = {}

function StateHandlers.Setup(Controller: any)
	local StateManager = Controller.StateManager
	local Character = Controller.Character

	StateManager:OnStateChanged(StateTypes.RAGDOLLED, function(_) -- IsRagdolled
		-- if IsRagdolled then
		-- else
		-- end
	end)

	StateManager:OnStateChanged(StateTypes.STUNNED, function(IsStunned)
		if IsStunned then
			Controller.Humanoid.WalkSpeed = 0
		else
			Controller.Humanoid.WalkSpeed = 16
		end
	end)

	StateManager:OnStateChanged(StateTypes.ATTACKING, function(_) -- IsAttacking
		-- if IsAttacking then
		-- else
		-- end
	end)

	StateManager:OnStateChanged(StateTypes.INVULNERABLE, function(IsInvulnerable)
		if IsInvulnerable then
			local ForceField = Instance.new("ForceField")
			ForceField.Parent = Character
		else
			local ForceField = Character:FindFirstChildOfClass("ForceField")
			if ForceField then
				ForceField:Destroy()
			end
		end
	end)
end

return StateHandlers