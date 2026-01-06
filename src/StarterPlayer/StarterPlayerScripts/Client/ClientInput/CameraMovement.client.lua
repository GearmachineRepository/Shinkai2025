--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CAMERA_OFFSET_SMOOTHING_SPEED = 20
local WAIT_TIMEOUT_SECONDS = 10

local RenderConnection: RBXScriptConnection? = nil
local CurrentSmoothedOffset = Vector3.zero
local ActiveCharacter: Model? = nil
local ActiveHumanoid: Humanoid? = nil

local function GetTorsoPart(Character: Model): BasePart?
	local UpperTorso = Character:FindFirstChild("UpperTorso")
	if UpperTorso and UpperTorso:IsA("BasePart") then
		return UpperTorso
	end

	local Torso = Character:FindFirstChild("Torso")
	if Torso and Torso:IsA("BasePart") then
		return Torso
	end

	return nil
end

local function DisconnectRender()
	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end
	ActiveCharacter = nil
	ActiveHumanoid = nil
end

local function ResetCameraOffset(Humanoid: Humanoid?)
	if Humanoid then
		Humanoid.CameraOffset = Vector3.zero
	end
	CurrentSmoothedOffset = Vector3.zero
end

local function WaitForHumanoid(Character: Model): Humanoid?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		return Humanoid
	end

	local StartTimeSeconds = os.clock()
	while os.clock() - StartTimeSeconds < WAIT_TIMEOUT_SECONDS do
		Humanoid = Character:FindFirstChildOfClass("Humanoid")
		if Humanoid then
			return Humanoid
		end
		RunService.Heartbeat:Wait()
	end

	return nil
end

local function WaitForRootPart(Character: Model): BasePart?
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end

	local StartTimeSeconds = os.clock()
	while os.clock() - StartTimeSeconds < WAIT_TIMEOUT_SECONDS do
		RootPart = Character:FindFirstChild("HumanoidRootPart")
		if RootPart and RootPart:IsA("BasePart") then
			return RootPart
		end
		RunService.Heartbeat:Wait()
	end

	return nil
end

local function WaitForTorsoPart(Character: Model): BasePart?
	local TorsoPart = GetTorsoPart(Character)
	if TorsoPart then
		return TorsoPart
	end

	local StartTimeSeconds = os.clock()
	while os.clock() - StartTimeSeconds < WAIT_TIMEOUT_SECONDS do
		TorsoPart = GetTorsoPart(Character)
		if TorsoPart then
			return TorsoPart
		end
		RunService.Heartbeat:Wait()
	end

	return nil
end

local function StartRenderLoop(Character: Model, Humanoid: Humanoid)
	DisconnectRender()

	ActiveCharacter = Character
	ActiveHumanoid = Humanoid
	ResetCameraOffset(Humanoid)

	RenderConnection = RunService.RenderStepped:Connect(function(DeltaTimeSeconds: number)
		local LiveCharacter = ActiveCharacter
		local LiveHumanoid = ActiveHumanoid
		if not LiveCharacter or not LiveHumanoid then
			DisconnectRender()
			return
		end

		if LiveHumanoid.Parent ~= LiveCharacter then
			DisconnectRender()
			return
		end

		local RootPart = LiveCharacter:FindFirstChild("HumanoidRootPart")
		if not RootPart or not RootPart:IsA("BasePart") then
			LiveHumanoid.CameraOffset = Vector3.zero
			return
		end

		local TorsoPart = GetTorsoPart(LiveCharacter)
		if not TorsoPart then
			LiveHumanoid.CameraOffset = Vector3.zero
			return
		end

		local RootToTorsoLocalPosition = TorsoPart.CFrame:ToObjectSpace(RootPart.CFrame).Position
		local TargetOffset = -RootToTorsoLocalPosition

		local ClampedDeltaTimeSeconds = math.clamp(DeltaTimeSeconds, 0, 1 / 15)
		local Alpha = 1 - math.exp(-CAMERA_OFFSET_SMOOTHING_SPEED * ClampedDeltaTimeSeconds)

		CurrentSmoothedOffset = CurrentSmoothedOffset:Lerp(TargetOffset, Alpha)
		LiveHumanoid.CameraOffset = CurrentSmoothedOffset
	end)
end

local function ConnectCharacter(Character: Model)
	DisconnectRender()

	local Humanoid = WaitForHumanoid(Character)
	if not Humanoid then
		return
	end

	local RootPart = WaitForRootPart(Character)
	if not RootPart then
		return
	end

	local TorsoPart = WaitForTorsoPart(Character)
	if not TorsoPart then
		return
	end

	StartRenderLoop(Character, Humanoid)
end

LocalPlayer.CharacterAdded:Connect(ConnectCharacter)
LocalPlayer.CharacterRemoving:Connect(function(Character: Model)
	if ActiveCharacter == Character then
		DisconnectRender()
	end
end)

local ExistingCharacter = LocalPlayer.Character
if ExistingCharacter then
	ConnectCharacter(ExistingCharacter)
end
