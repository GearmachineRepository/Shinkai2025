--!strict

local InteractableBase = {}

export type ActiveUser = {
	Connection: RBXScriptConnection,
	ActivityConnection: RBXScriptConnection?,
}

function InteractableBase.SetupJumpExit(Character: Model, OnExit: () -> ()): RBXScriptConnection
	return Character:GetAttributeChangedSignal("Jumping"):Connect(function()
		if Character:GetAttribute("Jumping") then
			OnExit()
		end
	end)
end

function InteractableBase.ClaimInteractable(InteractableModel: Model, Player: Player): boolean
	local CurrentUser = InteractableModel:GetAttribute("ActiveFor")
	if CurrentUser then
		return false
	end

	InteractableModel:SetAttribute("ActiveFor", Player.UserId)
	return true
end

function InteractableBase.ReleaseInteractable(InteractableModel: Model)
	InteractableModel:SetAttribute("ActiveFor", nil)
end

function InteractableBase.WeldToInteractable(Character: Model, Location: BasePart, WeldName: string): WeldConstraint?
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then
		return nil
	end

	HumanoidRootPart.CFrame = Location.CFrame

	local Weld = Instance.new("WeldConstraint")
	Weld.Name = WeldName
	Weld.Part0 = Location
	Weld.Part1 = HumanoidRootPart
	Weld.Parent = HumanoidRootPart

	return Weld
end

function InteractableBase.RemoveWeld(Character: Model, WeldName: string)
	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then
		return
	end

	local Weld = HumanoidRootPart:FindFirstChild(WeldName)
	if Weld then
		Weld:Destroy()
	end
end

function InteractableBase.ValidateBasicRequirements(Player: Player): (boolean, string?)
	local Character = Player.Character
	if not Character then
		return false, "No character found"
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return false, "Humanoid is dead or missing"
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if not HumanoidRootPart then
		return false, "No HumanoidRootPart found"
	end

	return true
end

local function CleanupTask(Task: any)
	if not Task then
		return
	end

	if typeof(Task) == "RBXScriptConnection" then
		Task:Disconnect()
		return
	end

	Task()
end

function InteractableBase.CleanupActiveUsers(Player: Player, ActiveUsers: { [Player]: ActiveUser })
	local UserData = ActiveUsers[Player]
	if not UserData then
		return
	end

	CleanupTask(UserData.Connection)
	CleanupTask(UserData.ActivityConnection)

	ActiveUsers[Player] = nil
end

return InteractableBase
