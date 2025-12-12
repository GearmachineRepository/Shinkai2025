--!strict

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Packets = require(Shared:WaitForChild("Networking"):WaitForChild("Packets"))
local AttackDefinitions = require(Shared:WaitForChild("Combat"):WaitForChild("AttackDefinitions"))

type AttackState = {
	ActionName: string,
	ComboIndex: number,
	StartTime: number,
	WeaponId: string,
	HitTargets: { [Instance]: boolean },
}

local PlayerAttackState: { [Player]: AttackState } = {}

local DISTANCE_BUFFER_STUDS: number = 2.0
local MIN_HIT_TIME_SKEW_SECONDS: number = 0.40
local MAX_HIT_TIME_SKEW_SECONDS: number = 0.60

local function GetCharacter(PlayerInstance: Player): Model?
	return PlayerInstance.Character
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

local function GetEquippedToolId(CharacterModel: Model): string
	local ToolInstance = CharacterModel:FindFirstChildOfClass("Tool")
	if ToolInstance == nil then
		return "Default"
	end
	return ToolInstance.Name
end

local function IsFacingWithinAngle(AttackerRoot: BasePart, TargetPosition: Vector3, AngleDegrees: number): boolean
	local Forward: Vector3 = AttackerRoot.CFrame.LookVector
	local ToTarget: Vector3 = (TargetPosition - AttackerRoot.Position)

	if ToTarget.Magnitude <= 0.001 then
		return true
	end

	local ToTargetUnit: Vector3 = ToTarget.Unit
	local DotValue: number = Forward:Dot(ToTargetUnit)
	local ClampedDot: number = math.clamp(DotValue, -1, 1)
	local AngleRadians: number = math.acos(ClampedDot)
	local AngleActualDegrees: number = math.deg(AngleRadians)

	return AngleActualDegrees <= (AngleDegrees * 0.5)
end

local function GetModelFromInstance(InstanceValue: Instance): Model?
	if InstanceValue:IsA("Model") then
		return InstanceValue
	end
	return InstanceValue:FindFirstAncestorOfClass("Model")
end

local function ValidateHitTime(AttackStart: number, Windup: number, Active: number, ClientHitTime: number): boolean
	local ServerNow: number = os.clock()

	if ClientHitTime < (ServerNow - MAX_HIT_TIME_SKEW_SECONDS) then
		return false
	end

	if ClientHitTime > (ServerNow + MIN_HIT_TIME_SKEW_SECONDS) then
		return false
	end

	local ActiveStart: number = AttackStart + Windup
	local ActiveEnd: number = ActiveStart + Active

	return ClientHitTime >= (ActiveStart - 0.15) and ClientHitTime <= (ActiveEnd + 0.15)
end

local function ApplyDamageToTarget(TargetModel: Model, DamageAmount: number): boolean
	local TargetHumanoid: Humanoid? = GetHumanoid(TargetModel)
	if TargetHumanoid == nil then
		return false
	end

	if TargetHumanoid.Health <= 0 then
		return false
	end

	TargetHumanoid:TakeDamage(DamageAmount)
	return true
end

Packets.RequestCombatAction.OnServerEvent:Connect(
	function(PlayerInstance: Player, ActionName: string, ComboIndex: number)
		if ActionName ~= "M1" then
			return
		end

		local CharacterModel: Model? = GetCharacter(PlayerInstance)
		if CharacterModel == nil then
			return
		end

		local AttackerHumanoid: Humanoid? = GetHumanoid(CharacterModel)
		if AttackerHumanoid == nil or AttackerHumanoid.Health <= 0 then
			return
		end

		local WeaponId: string = GetEquippedToolId(CharacterModel)

		PlayerAttackState[PlayerInstance] = {
			ActionName = ActionName,
			ComboIndex = ComboIndex,
			StartTime = os.clock(),
			WeaponId = WeaponId,
			HitTargets = {},
		}
	end
)

Packets.CombatHit.OnServerEvent:Connect(
	function(
		PlayerInstance: Player,
		TargetInstance: Instance,
		AttackName: string,
		HitPosition: Vector3,
		ClientHitTime: number
	)
		if AttackName ~= "M1" then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetInstance, 0, false, "InvalidAttack")
			return
		end

		local AttackStateValue: AttackState? = PlayerAttackState[PlayerInstance]
		if AttackStateValue == nil then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetInstance, 0, false, "NoAttackState")
			return
		end

		local CharacterModel: Model? = GetCharacter(PlayerInstance)
		if CharacterModel == nil then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetInstance, 0, false, "NoCharacter")
			return
		end

		local AttackerRoot: BasePart? = GetRootPart(CharacterModel)
		if AttackerRoot == nil then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetInstance, 0, false, "NoRoot")
			return
		end

		local TargetModel: Model? = GetModelFromInstance(TargetInstance)
		if TargetModel == nil then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetInstance, 0, false, "InvalidTarget")
			return
		end

		if AttackStateValue.HitTargets[TargetModel] == true then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, 0, false, "AlreadyHit")
			return
		end

		local TargetRoot: BasePart? = GetRootPart(TargetModel)
		if TargetRoot == nil then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, 0, false, "TargetNoRoot")
			return
		end

		local AttackDefinition =
			AttackDefinitions.GetM1Definition(AttackStateValue.WeaponId, AttackStateValue.ComboIndex)

		local MaxDistance: number = AttackDefinition.RangeStuds + DISTANCE_BUFFER_STUDS
		local ActualDistance: number = (TargetRoot.Position - AttackerRoot.Position).Magnitude
		if ActualDistance > MaxDistance then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, 0, false, "TooFar")
			return
		end

		if not IsFacingWithinAngle(AttackerRoot, TargetRoot.Position, AttackDefinition.AngleDegrees) then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, 0, false, "BadAngle")
			return
		end

		if
			not ValidateHitTime(
				AttackStateValue.StartTime,
				AttackDefinition.WindupSeconds,
				AttackDefinition.ActiveSeconds,
				ClientHitTime
			)
		then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, 0, false, "BadTime")
			return
		end

		local WasDamaged: boolean = ApplyDamageToTarget(TargetModel, AttackDefinition.Damage)
		if not WasDamaged then
			Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, 0, false, "NoDamageApplied")
			return
		end

		AttackStateValue.HitTargets[TargetModel] = true
		Packets.CombatHitConfirmed:FireClient(PlayerInstance, TargetModel, AttackDefinition.Damage, true, "OK")
		Packets.CombatHitRegistered:Fire(TargetModel, AttackName, HitPosition)
	end
)

Players.PlayerRemoving:Connect(function(PlayerInstance: Player)
	PlayerAttackState[PlayerInstance] = nil
end)
