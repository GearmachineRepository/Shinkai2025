--!strict

local AngleValidator = {}

local function GetCharacterLookVector(Character: Model): Vector3?
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return nil
	end

	return RootPart.CFrame.LookVector
end

local function GetCharacterPosition(Character: Model): Vector3?
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return nil
	end

	return RootPart.Position
end

function AngleValidator.GetAngleBetween(DefenderCharacter: Model, AttackerCharacter: Model): number?
	local DefenderPosition = GetCharacterPosition(DefenderCharacter)
	local AttackerPosition = GetCharacterPosition(AttackerCharacter)
	local DefenderLookVector = GetCharacterLookVector(DefenderCharacter)

	if not DefenderPosition or not AttackerPosition or not DefenderLookVector then
		return nil
	end

	local DirectionToAttacker = (AttackerPosition - DefenderPosition).Unit
	local FlatLookVector = Vector3.new(DefenderLookVector.X, 0, DefenderLookVector.Z).Unit
	local FlatDirectionToAttacker = Vector3.new(DirectionToAttacker.X, 0, DirectionToAttacker.Z).Unit

	local DotProduct = FlatLookVector:Dot(FlatDirectionToAttacker)
	local AngleRadians = math.acos(math.clamp(DotProduct, -1, 1))
	local AngleDegrees = math.deg(AngleRadians)

	return AngleDegrees
end

function AngleValidator.IsWithinAngle(DefenderCharacter: Model, AttackerCharacter: Model, MaxAngle: number): boolean
	local Angle = AngleValidator.GetAngleBetween(DefenderCharacter, AttackerCharacter)

	if not Angle then
		return true
	end

	return Angle <= MaxAngle
end

function AngleValidator.IsAttackFromBehind(DefenderCharacter: Model, AttackerCharacter: Model, FrontAngle: number?): boolean
	local HalfAngle = (FrontAngle or 180) / 2
	return not AngleValidator.IsWithinAngle(DefenderCharacter, AttackerCharacter, HalfAngle)
end

return AngleValidator