--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CAMERA_OFFSET_SMOOTHING_SPEED = 20

local RenderConnection: RBXScriptConnection? = nil
local CurrentSmoothedOffset = Vector3.zero

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
end

local function ConnectCharacter(Character: Model)
	DisconnectRender()

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	local RootPart = Humanoid.RootPart
	if not RootPart or not RootPart:IsA("BasePart") then
		return
	end

	CurrentSmoothedOffset = Vector3.zero
	Humanoid.CameraOffset = Vector3.zero

	RenderConnection = RunService.RenderStepped:Connect(function(DeltaTimeSeconds: number)
		if Humanoid.Parent ~= Character then
			return
		end

		local LiveRootPart = Humanoid.RootPart
		if not LiveRootPart or not LiveRootPart:IsA("BasePart") then
			Humanoid.CameraOffset = Vector3.zero
			return
		end

		local TorsoPart = GetTorsoPart(Character)
		if not TorsoPart then
			Humanoid.CameraOffset = Vector3.zero
			return
		end

		local RootToTorsoLocalPosition = TorsoPart.CFrame:ToObjectSpace(LiveRootPart.CFrame).Position

		local TargetOffset = Vector3.new(-RootToTorsoLocalPosition.X, -RootToTorsoLocalPosition.Y, -RootToTorsoLocalPosition.Z)

		local ClampedDeltaTimeSeconds = math.clamp(DeltaTimeSeconds, 0, 1 / 15)
		local Alpha = 1 - math.exp(-CAMERA_OFFSET_SMOOTHING_SPEED * ClampedDeltaTimeSeconds)

		CurrentSmoothedOffset = CurrentSmoothedOffset:Lerp(TargetOffset, Alpha)
		Humanoid.CameraOffset = CurrentSmoothedOffset
	end)
end

local function OnCharacterAdded(Character: Model)
	ConnectCharacter(Character)
end

local function OnCharacterRemoving()
	DisconnectRender()
end

LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)
LocalPlayer.CharacterRemoving:Connect(OnCharacterRemoving)

if LocalPlayer.Character then
	ConnectCharacter(LocalPlayer.Character)
end
