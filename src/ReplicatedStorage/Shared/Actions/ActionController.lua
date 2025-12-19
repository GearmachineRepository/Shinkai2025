--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ActionRegistry = require(Shared.Actions.ActionRegistry)
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer

local ActionController = {}

local ActiveCooldowns: { [string]: boolean } = {}
local PendingActions: { [string]: { Action: any, Context: any, RollbackData: any? } } = {}
local CurrentlyPressedKeys: { [Enum.KeyCode]: boolean } = {}

local DIRECTION_KEYS = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.D] = true,
}

function ActionController.GetCharacter(): Model?
	return Player.Character
end

function ActionController.GetHumanoidRootPart(): Part?
	local Character = ActionController.GetCharacter()
	if not Character then
		return nil
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
		return HumanoidRootPart :: Part
	end

	return nil
end

function ActionController.GetDashDirection(): Vector3?
	local Camera = workspace.CurrentCamera
	if not Camera then
		return nil
	end

	local CameraLookVector = Camera.CFrame.LookVector
	local CameraRightVector = Camera.CFrame.RightVector

	local Forward = if CurrentlyPressedKeys[Enum.KeyCode.W] then CameraLookVector else Vector3.zero
	local Backward = if CurrentlyPressedKeys[Enum.KeyCode.S] then -CameraLookVector else Vector3.zero
	local Left = if CurrentlyPressedKeys[Enum.KeyCode.A] then -CameraRightVector else Vector3.zero
	local Right = if CurrentlyPressedKeys[Enum.KeyCode.D] then CameraRightVector else Vector3.zero

	local Direction = Forward + Backward + Left + Right

	if Direction.Magnitude > 0 then
		return Vector3.new(Direction.X, 0, Direction.Z).Unit
	end

	return nil
end

function ActionController.IsOnCooldown(ActionName: string): boolean
	return ActiveCooldowns[ActionName] == true
end

function ActionController.CanPerformAction(ActionName: string, ActionData: any?): (boolean, string?)
	local Action = ActionRegistry.Get(ActionName)
	if not Action then
		return false, "ActionNotFound"
	end

	if ActionController.IsOnCooldown(ActionName) then
		return false, "OnCooldown"
	end

	local Character = ActionController.GetCharacter()
	if not Character then
		return false, "NoCharacter"
	end

	local Context = {
		Entity = nil,
		Character = Character,
		Player = Player,
		ActionData = ActionData,
	}

	local ValidationResult = Action:CanExecute(Context)
	return ValidationResult.Success, ValidationResult.Reason
end

function ActionController.RequestAction(ActionName: string, ActionData: any?)
	local CanPerform, _Reason = ActionController.CanPerformAction(ActionName, ActionData)
	if not CanPerform then
		return
	end

	local Action = ActionRegistry.Get(ActionName)
	if not Action then
		return
	end

	local Character = ActionController.GetCharacter()
	if not Character then
		return
	end

	local Context = {
		Entity = nil,
		Character = Character,
		Player = Player,
		ActionData = ActionData,
	}

	local Result = Action:ExecuteClient(Context)

	if Result.Success then
		PendingActions[ActionName] = {
			Action = Action,
			Context = Context,
			RollbackData = Result.RollbackData,
		}

		Packets.PerformAction:Fire(ActionName, ActionData)
	end
end

function ActionController.RequestDash()
	local Direction = ActionController.GetDashDirection()
	if not Direction then
		return
	end

	ActionController.RequestAction("Dash", { Direction = Direction })
end

function ActionController.OnActionApproved(ActionName: string)
	PendingActions[ActionName] = nil
end

function ActionController.OnActionDenied(ActionName: string, _Reason: string?)
	local PendingAction = PendingActions[ActionName]
	if not PendingAction then
		return
	end

	warn(string.format("[ROLLBACK] Action '%s' was denied by server. Rolling back...", ActionName))

	PendingAction.Action:RollbackClient(PendingAction.Context, PendingAction.RollbackData)
	PendingActions[ActionName] = nil
end

function ActionController.StartCooldown(ActionName: string, _StartTime: number, Duration: number)
	ActiveCooldowns[ActionName] = true

	task.delay(Duration, function()
		ActiveCooldowns[ActionName] = nil
	end)
end

function ActionController.SetKeyPressed(KeyCode: Enum.KeyCode, IsPressed: boolean)
	if DIRECTION_KEYS[KeyCode] then
		CurrentlyPressedKeys[KeyCode] = if IsPressed then true else nil
	end
end

function ActionController.Initialize()
	Packets.ActionApproved.OnClientEvent:Connect(ActionController.OnActionApproved)

	Packets.ActionDenied.OnClientEvent:Connect(ActionController.OnActionDenied)

	Packets.StartCooldown.OnClientEvent:Connect(ActionController.StartCooldown)
end

return ActionController
