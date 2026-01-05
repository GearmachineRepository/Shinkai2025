--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PhysicsBalance = require(Shared.Config.Balance.PhysicsBalance)
local AnimationService = require(Shared.Services.AnimationService)
local AnimationDatabase = require(Shared.Config.Data.AnimationDatabase)

local Player = Players.LocalPlayer

local ClientDodgeHandler = {}

type DodgeState = {
	IsActive: boolean,
	BodyVelocity: BodyVelocity?,
	AnimationKey: string?,
	Connection: RBXScriptConnection?,
	StartTime: number,
	LastSteerDirection: Vector3,
	IsSteerable: boolean,
}

local ActiveDodge: DodgeState? = nil

local DODGE_SPEED = PhysicsBalance.Dash.Speed
local DODGE_DURATION = PhysicsBalance.Dash.Duration

local DODGE_MAX_FORCE = Vector3.new(PhysicsBalance.Dash.MaxForce, 0, PhysicsBalance.Dash.MaxForce)

local DIRECTION_TO_ANIMATION: { [string]: string } = {
	Forward = "DashForward",
	Back = "DashBack",
	Left = "DashLeft",
	Right = "DashRight",
}

local function GetCharacter(): Model?
	return Player.Character
end

local function GetRootPart(): BasePart?
	local Character = GetCharacter()
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function GetFlatCharacterBasis(): (Vector3, Vector3)
	local RootPart = GetRootPart()
	if not RootPart then
		return Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)
	end

	local CharacterLook = RootPart.CFrame.LookVector
	local FlatForward = Vector3.new(CharacterLook.X, 0, CharacterLook.Z)
	if FlatForward.Magnitude < 0.001 then
		FlatForward = Vector3.new(0, 0, -1)
	else
		FlatForward = FlatForward.Unit
	end

	local FlatRight = Vector3.new(-FlatForward.Z, 0, FlatForward.X)
	return FlatForward, FlatRight
end

local function GetCharacterRelativeMoveDirection(): Vector3
	local RootPart = GetRootPart()
	if not RootPart then
		return Vector3.zero
	end

	local CharacterForward = RootPart.CFrame.LookVector
	local FlatForward = Vector3.new(CharacterForward.X, 0, CharacterForward.Z)
	if FlatForward.Magnitude < 0.001 then
		FlatForward = Vector3.new(0, 0, -1)
	else
		FlatForward = FlatForward.Unit
	end

	local FlatRight = Vector3.new(-FlatForward.Z, 0, FlatForward.X)

	local MoveVector = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		MoveVector = MoveVector + FlatForward
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		MoveVector = MoveVector - FlatForward
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		MoveVector = MoveVector - FlatRight
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		MoveVector = MoveVector + FlatRight
	end

	if MoveVector.Magnitude < 0.1 then
		return Vector3.zero
	end

	return MoveVector.Unit
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

local function GetAnimationKeyForDirection(DirectionName: string): string?
	local AnimationKey = DIRECTION_TO_ANIMATION[DirectionName]
	if not AnimationKey then
		return nil
	end

	local AnimationId = AnimationDatabase[AnimationKey]
	if not AnimationId then
		return nil
	end

	return AnimationKey
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

	local FlatMove = GetCharacterRelativeMoveDirection()

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

local function PreloadDodgeAnimations()
	local AnimationsToPreload: { [string]: string } = {}
	for _, AnimationKey in DIRECTION_TO_ANIMATION do
		local AnimationId = AnimationDatabase[AnimationKey]
		if AnimationId then
			AnimationsToPreload[AnimationKey] = AnimationId
		end
	end

	AnimationService.Preload(Player, AnimationsToPreload)
end

function ClientDodgeHandler.Init()
	PreloadDodgeAnimations()

	Player.CharacterAdded:Connect(function()
		ClientDodgeHandler.Rollback()
		task.wait(0.5)
		PreloadDodgeAnimations()
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

	local FlatForward, FlatRight = GetFlatCharacterBasis()
	local FlatMove = GetCharacterRelativeMoveDirection()

	if FlatMove.Magnitude < 0.1 then
		FlatMove = -FlatForward
	end

	local DirectionName, CardinalDirection = GetCardinalFromMove(FlatForward, FlatRight, FlatMove)
	local AnimationKey = GetAnimationKeyForDirection(DirectionName)

	local BodyVelocityInstance = CreateBodyVelocity(CardinalDirection)
	if not BodyVelocityInstance then
		return false
	end

	if AnimationKey then
		AnimationService.Play(Player, AnimationKey)
	end

	ActiveDodge = {
		IsActive = true,
		BodyVelocity = BodyVelocityInstance,
		AnimationKey = AnimationKey,
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

	if CurrentDodge.AnimationKey then
		AnimationService.Stop(Player, CurrentDodge.AnimationKey, 0.15)
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