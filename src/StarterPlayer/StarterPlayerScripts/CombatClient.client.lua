--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LOCAL_PLAYER: Player = Players.LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packets = require(Shared:WaitForChild("Networking"):WaitForChild("Packets"))
local AttackDefinitions = require(Shared:WaitForChild("Combat"):WaitForChild("AttackDefinitions"))

local MAX_COMBO: number = 3
local COMBO_RESET_SECONDS: number = 0.9

local LastM1Time: number = 0
local ComboIndex: number = 0
local LocalAttackLockedUntil: number = 0

local function GetCharacter(): Model?
	return LOCAL_PLAYER.Character
end

local function GetHumanoid(CharacterModel: Model): Humanoid?
	local HumanoidInstance = CharacterModel:FindFirstChildOfClass("Humanoid")
	if HumanoidInstance == nil then
		return nil
	end
	return HumanoidInstance
end

local function GetRootPart(CharacterModel: Model): BasePart?
	local RootPart = CharacterModel:FindFirstChild("HumanoidRootPart")
	if RootPart == nil or not RootPart:IsA("BasePart") then
		return nil
	end
	return RootPart
end

local function GetEquippedTool(CharacterModel: Model): Tool?
	local ToolInstance = CharacterModel:FindFirstChildOfClass("Tool")
	return ToolInstance
end

local function ComputeNextComboIndex(): number
	local CurrentTime: number = os.clock()
	if (CurrentTime - LastM1Time) > COMBO_RESET_SECONDS then
		return 1
	end

	local NextIndex: number = ComboIndex + 1
	if NextIndex > MAX_COMBO then
		return 1
	end

	return NextIndex
end

local function FindHumanoidFromPart(PartInstance: BasePart): Humanoid?
	local Current: Instance? = PartInstance
	while Current ~= nil do
		if Current:IsA("Model") then
			local HumanoidInstance = Current:FindFirstChildOfClass("Humanoid")
			if HumanoidInstance ~= nil then
				return HumanoidInstance
			end
		end
		Current = Current.Parent
	end
	return nil
end

local function PerformM1Hitbox(WeaponId: string, CurrentComboIndex: number): ()
	local CharacterModel: Model? = GetCharacter()
	if CharacterModel == nil then
		return
	end

	local RootPart: BasePart? = GetRootPart(CharacterModel)
	if RootPart == nil then
		return
	end

	local AttackDefinition = AttackDefinitions.GetM1Definition(WeaponId, CurrentComboIndex)
	local HitboxCFrame: CFrame = RootPart.CFrame * CFrame.new(AttackDefinition.HitboxOffset)

	local OverlapParameters = OverlapParams.new()
	OverlapParameters.FilterType = Enum.RaycastFilterType.Exclude
	OverlapParameters.FilterDescendantsInstances = { CharacterModel }
	OverlapParameters.RespectCanCollide = false

	local Parts: { BasePart } =
		Workspace:GetPartBoundsInBox(HitboxCFrame, AttackDefinition.HitboxSize, OverlapParameters)

	local ClosestHumanoid: Humanoid? = nil
	local ClosestDistance: number = math.huge
	local HitPosition: Vector3 = HitboxCFrame.Position

	for _, PartInstance: BasePart in Parts do
		local CandidateHumanoid: Humanoid? = FindHumanoidFromPart(PartInstance)
		if CandidateHumanoid ~= nil and CandidateHumanoid.Health > 0 then
			local CandidateModel: Model? = CandidateHumanoid.Parent
			if CandidateModel ~= nil then
				local CandidateRoot: BasePart? = GetRootPart(CandidateModel)
				if CandidateRoot ~= nil then
					local Distance: number = (CandidateRoot.Position - RootPart.Position).Magnitude
					if Distance < ClosestDistance then
						ClosestDistance = Distance
						ClosestHumanoid = CandidateHumanoid
						HitPosition = CandidateRoot.Position
					end
				end
			end
		end
	end

	if ClosestHumanoid == nil then
		return
	end

	local TargetModel: Model? = ClosestHumanoid.Parent
	if TargetModel == nil then
		return
	end

	Packets.CombatHit:Fire(TargetModel, "M1", HitPosition, os.clock())
end

local function TryM1(): ()
	local CurrentTime: number = os.clock()
	if CurrentTime < LocalAttackLockedUntil then
		return
	end

	local CharacterModel: Model? = GetCharacter()
	if CharacterModel == nil then
		return
	end

	local HumanoidInstance: Humanoid? = GetHumanoid(CharacterModel)
	if HumanoidInstance == nil or HumanoidInstance.Health <= 0 then
		return
	end

	local ToolInstance: Tool? = GetEquippedTool(CharacterModel)
	if ToolInstance == nil then
		return
	end

	local WeaponId: string = ToolInstance.Name
	local NextComboIndex: number = ComputeNextComboIndex()
	local AttackDefinition = AttackDefinitions.GetM1Definition(WeaponId, NextComboIndex)

	ComboIndex = NextComboIndex
	LastM1Time = CurrentTime
	LocalAttackLockedUntil = CurrentTime
		+ AttackDefinition.WindupSeconds
		+ AttackDefinition.ActiveSeconds
		+ AttackDefinition.RecoverySeconds

	Packets.RequestCombatAction:Fire("M1", NextComboIndex)

	task.delay(AttackDefinition.WindupSeconds, function()
		PerformM1Hitbox(WeaponId, NextComboIndex)
	end)
end

Packets.CombatHitConfirmed.OnClientEvent:Connect(
	function(TargetInstance: Instance, DamageAmount: number, WasAccepted: boolean, Reason: string)
		if not WasAccepted then
			return
		end
	end
)

UserInputService.InputBegan:Connect(function(InputObject: InputObject, WasProcessed: boolean)
	if WasProcessed then
		return
	end

	if InputObject.UserInputType == Enum.UserInputType.MouseButton1 then
		TryM1()
	end
end)
