--!strict

local LatencyCompensation = require(script.Parent.LatencyCompensation)
local ActionExecutor = require(script.Parent.Parent.Core.ActionExecutor)

local HitValidation = {}

type Entity = {
	Character: Model,
	Player: Player?,
	States: any,
	GetComponent: (self: Entity, Name: string) -> any?,
}

type ActionContext = {
	Entity: Entity,
	InputData: { [string]: any },
	Metadata: {
		HitboxSize: Vector3?,
		HitboxOffset: Vector3?,
		[string]: any,
	},
	CustomData: { [string]: any },
}

type ValidationResult = {
	IsValid: boolean,
	Reason: string?,
	RewindedPosition: Vector3?,
}

HitValidation.POSITION_TOLERANCE = 2.0
HitValidation.ENABLE_STRICT_VALIDATION = false

function HitValidation.ValidateHit(
	AttackerContext: ActionContext,
	Target: Entity,
	CurrentHitPosition: Vector3?
): ValidationResult
	local InputTimestamp = AttackerContext.InputData and AttackerContext.InputData.InputTimestamp
	local RewindTime = LatencyCompensation.GetCompensation(InputTimestamp)

	if RewindTime <= 0 then
		return {
			IsValid = true,
			Reason = "NoCompensationNeeded",
			RewindedPosition = CurrentHitPosition,
		}
	end

	local PositionHistory = Target:GetComponent("PositionHistory")
	if not PositionHistory then
		return {
			IsValid = true,
			Reason = "NoPositionHistory",
			RewindedPosition = CurrentHitPosition,
		}
	end

	local AttackerCharacter = AttackerContext.Entity.Character
	if not AttackerCharacter then
		return {
			IsValid = false,
			Reason = "NoAttackerCharacter",
			RewindedPosition = nil,
		}
	end

	local AttackerRoot = AttackerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not AttackerRoot then
		return {
			IsValid = false,
			Reason = "NoAttackerRootPart",
			RewindedPosition = nil,
		}
	end

	local Metadata = AttackerContext.Metadata
	local HitboxSize = Metadata.HitboxSize or Vector3.new(4, 4, 4)
	local HitboxOffset = Metadata.HitboxOffset or Vector3.new(0, 0, -3)

	local WasInRange = PositionHistory:WasInHitbox(
		AttackerRoot.CFrame,
		HitboxSize + Vector3.new(HitValidation.POSITION_TOLERANCE, HitValidation.POSITION_TOLERANCE, HitValidation.POSITION_TOLERANCE),
		HitboxOffset,
		RewindTime
	)

	if not WasInRange and HitValidation.ENABLE_STRICT_VALIDATION then
		return {
			IsValid = false,
			Reason = "OutOfRangeAtInputTime",
			RewindedPosition = nil,
		}
	end

	local TargetTime = workspace:GetServerTimeNow() - RewindTime
	local RewindedPosition = PositionHistory:GetPositionAtTime(TargetTime)

	return {
		IsValid = true,
		Reason = if WasInRange then "ValidatedWithRewind" else "PassedWithTolerance",
		RewindedPosition = RewindedPosition or CurrentHitPosition,
	}
end

function HitValidation.ShouldFavorDefender(
	Target: Entity,
	GraceWindowSeconds: number
): boolean
	local PositionHistory = Target:GetComponent("PositionHistory")
	if not PositionHistory then
		return false
	end

	local States = Target:GetComponent("States")
	if not States then
		return false
	end

	local IsDodging = States:GetState("Dodging")
	local IsInvulnerable = States:GetState("Invulnerable")

	if IsInvulnerable then
		return true
	end

	if not IsDodging then
		return false
	end

	local TargetContext = ActionExecutor.GetActiveContext(Target :: any)

	if not TargetContext then
		return false
	end

	if TargetContext.Metadata.ActionName ~= "Dodge" then
		return false
	end

	local DodgeInputTimestamp = TargetContext.InputData and TargetContext.InputData.InputTimestamp
	if not DodgeInputTimestamp then
		return false
	end

	local InputAge = workspace:GetServerTimeNow() - DodgeInputTimestamp
	local IFramesDuration = TargetContext.Metadata.IFramesDuration or 0.3

	if InputAge < IFramesDuration + GraceWindowSeconds then
		return true
	end

	return false
end

function HitValidation.GetDefenderInputAge(Target: Entity): number?
	local TargetContext = ActionExecutor.GetActiveContext(Target :: any)

	if not TargetContext then
		return nil
	end

	local InputTimestamp = TargetContext.InputData and TargetContext.InputData.InputTimestamp
	if not InputTimestamp then
		return nil
	end

	return workspace:GetServerTimeNow() - InputTimestamp
end

return HitValidation