--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DashBalance = require(Shared.Configurations.Balance.DashBalance)

local Player = Players.LocalPlayer

local ClientDodgeHandler = {}

type DodgeState = {
	IsActive: boolean,
	BodyVelocity: BodyVelocity?,
	AnimationTrack: AnimationTrack?,
	Connection: RBXScriptConnection?,
	StartTime: number,
	LastSteerDirection: Vector3,
	IsSteerable: boolean,
}

local ActiveDodge: DodgeState? = nil

local DODGE_SPEED = DashBalance.Speed
local DODGE_DURATION = DashBalance.Duration

local DODGE_MAX_FORCE = Vector3.new(DashBalance.MaxForce, 0, DashBalance.MaxForce)

local DodgeAnimations = {
	Forward = nil :: Animation?,
	Back = nil :: Animation?,
	Left = nil :: Animation?,
	Right = nil :: Animation?,
}

local LoadedTracks = {
	Forward = nil :: AnimationTrack?,
	Back = nil :: AnimationTrack?,
	Left = nil :: AnimationTrack?,
	Right = nil :: AnimationTrack?,
}

local function GetCharacter(): Model?
	return Player.Character
end

local function GetHumanoid(): Humanoid?
	local Character = GetCharacter()
	if not Character then
		return nil
	end
	return Character:FindFirstChildOfClass("Humanoid")
end

local function GetRootPart(): BasePart?
	local Character = GetCharacter()
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function GetAnimator(): Animator?
	local Humanoid = GetHumanoid()
	if not Humanoid then
		return nil
	end
	return Humanoid:FindFirstChildOfClass("Animator")
end

local function GetFlatCameraBasis(): (Vector3, Vector3)
	local CurrentCamera = Workspace.CurrentCamera
	if not CurrentCamera then
		return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
	end

	local CameraLook = CurrentCamera.CFrame.LookVector
	local FlatForward = Vector3.new(CameraLook.X, 0, CameraLook.Z)
	if FlatForward.Magnitude < 0.001 then
		FlatForward = Vector3.new(0, 0, -1)
	else
		FlatForward = FlatForward.Unit
	end

	local FlatRight = Vector3.new(-FlatForward.Z, 0, FlatForward.X)
	return FlatForward, FlatRight
end

local function GetFlatMoveDirection(): Vector3
	local Humanoid = GetHumanoid()
	if not Humanoid then
		return Vector3.zero
	end

	local MoveDirection = Humanoid.MoveDirection
	local FlatMove = Vector3.new(MoveDirection.X, 0, MoveDirection.Z)
	if FlatMove.Magnitude < 0.1 then
		return Vector3.zero
	end

	return FlatMove.Unit
end

local function GetCardinalFromMove(FlatForward: Vector3, FlatRight: Vector3, FlatMove: Vector3): (string, Vector3)
	local ForwardComponent = FlatMove:Dot(FlatForward)
	local RightComponent = FlatMove:Dot(FlatRight)

	if math.abs(ForwardComponent) >= math.abs(RightComponent) then
		if ForwardComponent >= 0 then
			return "Forward", FlatForward
		else
			return "Back", -FlatForward
		end
	else
		if RightComponent >= 0 then
			return "Right", FlatRight
		else
			return "Left", -FlatRight
		end
	end
end

local function LoadDodgeAnimations()
	local Animator = GetAnimator()
	if not Animator then
		return
	end

	local AnimationsFolder = ReplicatedStorage:FindFirstChild("Animations")
	if not AnimationsFolder then
		return
	end

	local DodgeFolder = AnimationsFolder:FindFirstChild("Dodge")
	if not DodgeFolder then
		return
	end

	local Directions = { "Forward", "Back", "Left", "Right" }
	for _, DirectionName in Directions do
		local AnimationInstance = DodgeFolder:FindFirstChild(DirectionName) :: Animation?
		if AnimationInstance and AnimationInstance:IsA("Animation") then
			DodgeAnimations[DirectionName] = AnimationInstance
			LoadedTracks[DirectionName] = Animator:LoadAnimation(AnimationInstance)
		end
	end
end

local function GetDodgeTrack(DirectionName: string): AnimationTrack?
	local Track = LoadedTracks[DirectionName]
	if Track then
		return Track
	end

	local Animator = GetAnimator()
	local AnimationInstance = DodgeAnimations[DirectionName]
	if Animator and AnimationInstance then
		Track = Animator:LoadAnimation(AnimationInstance)
		LoadedTracks[DirectionName] = Track
		return Track
	end

	return nil
end

local function CreateBodyVelocity(InitialDirection: Vector3): BodyVelocity?
	local RootPart = GetRootPart()
	if not RootPart then
		return nil
	end

	local BodyVelocityInstance = Instance.new("BodyVelocity")
	BodyVelocityInstance.Name = "ClientDodgeVelocity"
	BodyVelocityInstance.MaxForce = DODGE_MAX_FORCE
	BodyVelocityInstance.Velocity = InitialDirection * DODGE_SPEED
	BodyVelocityInstance.Parent = RootPart

	return BodyVelocityInstance
end

local function UpdateDodgeVelocity()
	local CurrentDodge = ActiveDodge
	if not CurrentDodge or not CurrentDodge.IsActive then
		return
	end

	if not CurrentDodge.IsSteerable then
		return
	end

	local BodyVelocityInstance = CurrentDodge.BodyVelocity
	if not BodyVelocityInstance or not BodyVelocityInstance.Parent then
		return
	end

	local _FlatForward, _FlatRight = GetFlatCameraBasis()
	local FlatMove = GetFlatMoveDirection()

	if FlatMove.Magnitude < 0.1 then
		BodyVelocityInstance.Velocity = CurrentDodge.LastSteerDirection * DODGE_SPEED
		return
	end

	CurrentDodge.LastSteerDirection = FlatMove
	BodyVelocityInstance.Velocity = FlatMove * DODGE_SPEED
end

local function StartDodgeLoop()
	local CurrentDodge = ActiveDodge
	if not CurrentDodge then
		return
	end
	if CurrentDodge.Connection then
		return
	end

	CurrentDodge.Connection = RunService.RenderStepped:Connect(function()
		local ActiveState = ActiveDodge
		if not ActiveState or not ActiveState.IsActive then
			return
		end

		local Elapsed = os.clock() - ActiveState.StartTime
		if Elapsed >= DODGE_DURATION then
			ClientDodgeHandler.StopDodge()
			return
		end

		UpdateDodgeVelocity()
	end)
end

function ClientDodgeHandler.Init()
	LoadDodgeAnimations()

	Player.CharacterAdded:Connect(function()
		ClientDodgeHandler.Rollback()
		task.wait(0.5)
		LoadDodgeAnimations()
	end)
end

function ClientDodgeHandler.StartDodge(Steerable: boolean?): boolean
	if ActiveDodge and ActiveDodge.IsActive then
		return false
	end

	local RootPart = GetRootPart()
	if not RootPart then
		return false
	end

	local FlatForward, FlatRight = GetFlatCameraBasis()
	local FlatMove = GetFlatMoveDirection()

	if FlatMove.Magnitude < 0.1 then
		FlatMove = FlatForward
	end

	local DirectionName, CardinalDirection = GetCardinalFromMove(FlatForward, FlatRight, FlatMove)
	local Track = GetDodgeTrack(DirectionName)

	local BodyVelocityInstance = CreateBodyVelocity(CardinalDirection)
	if not BodyVelocityInstance then
		return false
	end

	if Track then
		Track:Play(0.1)
	end

	ActiveDodge = {
		IsActive = true,
		BodyVelocity = BodyVelocityInstance,
		AnimationTrack = Track,
		Connection = nil,
		StartTime = os.clock(),
		LastSteerDirection = CardinalDirection,
		IsSteerable = Steerable == true,
	}

	StartDodgeLoop()
	return true
end

function ClientDodgeHandler.StopDodge()
	local CurrentDodge = ActiveDodge
	if not CurrentDodge then
		return
	end

	CurrentDodge.IsActive = false

	if CurrentDodge.Connection then
		CurrentDodge.Connection:Disconnect()
		CurrentDodge.Connection = nil
	end

	if CurrentDodge.BodyVelocity and CurrentDodge.BodyVelocity.Parent then
		CurrentDodge.BodyVelocity:Destroy()
	end

	ActiveDodge = nil
end

function ClientDodgeHandler.Rollback()
	local CurrentDodge = ActiveDodge
	if not CurrentDodge then
		return
	end

	CurrentDodge.IsActive = false

	if CurrentDodge.Connection then
		CurrentDodge.Connection:Disconnect()
		CurrentDodge.Connection = nil
	end

	if CurrentDodge.AnimationTrack then
		CurrentDodge.AnimationTrack:Stop(0.1)
	end

	if CurrentDodge.BodyVelocity and CurrentDodge.BodyVelocity.Parent then
		CurrentDodge.BodyVelocity:Destroy()
	end

	ActiveDodge = nil
end

function ClientDodgeHandler.IsActive(): boolean
	return ActiveDodge ~= nil and ActiveDodge.IsActive
end

function ClientDodgeHandler.GetRemainingTime(): number
	local CurrentDodge = ActiveDodge
	if not CurrentDodge or not CurrentDodge.IsActive then
		return 0
	end

	local Elapsed = os.clock() - CurrentDodge.StartTime
	return math.max(0, DODGE_DURATION - Elapsed)
end

function ClientDodgeHandler.SetSpeed(Speed: number)
	DODGE_SPEED = Speed
end

function ClientDodgeHandler.SetDuration(Duration: number)
	DODGE_DURATION = Duration
end

return ClientDodgeHandler
