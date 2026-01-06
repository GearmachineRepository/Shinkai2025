--!nonstrict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Character references
local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
local Pose = "Standing"

-- Feature flags
local UserNoUpdateOnLoopSuccess, UserNoUpdateOnLoopValue = pcall(function()
	return UserSettings():IsUserFeatureEnabled("UserNoUpdateOnLoop")
end)
local UserNoUpdateOnLoop = UserNoUpdateOnLoopSuccess and UserNoUpdateOnLoopValue

local UserAnimateScaleRunSuccess, UserAnimateScaleRunValue = pcall(function()
	return UserSettings():IsUserFeatureEnabled("UserAnimateScaleRun")
end)
local UserAnimateScaleRun = UserAnimateScaleRunSuccess and UserAnimateScaleRunValue

-- Shared config/modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Configurations = Shared:WaitForChild("Config")

local CharacterBalance = require(Configurations.Balance.CharacterBalance)
local StyleConfigModule = require(Configurations.Styles.StyleConfig)
local ItemDatabase = require(Configurations.Data.ItemDatabase)
local AnimationDatabase = require(Configurations.Data.AnimationDatabase)

-- Animator
local Animator = Humanoid:FindFirstChildOfClass("Animator")
if not Animator then
	Animator = Instance.new("Animator")
	Animator.Parent = Humanoid
end

Humanoid.JumpPower = CharacterBalance.Movement.JumpPower

-- Constants
local JUMP_COOLDOWN_SECONDS: number = CharacterBalance.Movement.JumpCooldownSeconds
local SMALL_BUT_NOT_ZERO: number = 0.0001

local MOVEMENT_TRANSITION_TIME: number = 0.2

local FALL_TRANSITION_TIME: number = 0.2
local JUMP_ANIM_DURATION: number = 0.31

local HUMANOID_HIP_HEIGHT: number = 2

local SCALE_DAMPENING_PERCENT: number = 1.0

-- State
local JumpAnimTime = 0
local LastTick = time()

local CurrentAnim = ""
local CurrentAnimInstance: Animation? = nil
local CurrentAnimTrack: AnimationTrack? = nil
local CurrentAnimKeyframeHandler: RBXScriptConnection? = nil
local CurrentAnimSpeed = 1.0

local RunAnimTrack: AnimationTrack? = nil
local JogAnimTrack: AnimationTrack? = nil

local CurrentlyPlayingEmote = false
local PreloadedAnims: { [string]: boolean } = {}

-- Types
type FileListEntry = { id: string, weight: number }
type AnimEntry = { anim: Animation, weight: number }
type AnimSetTable = {
	count: number,
	totalWeight: number,
	[number]: AnimEntry,
}

local AnimTable: { [string]: AnimSetTable } = {}

-- Catalog
local AnimNames: { [string]: { FileListEntry } } = {
	idle = {
		{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 },
	},
	walk = {
		{ id = "rbxassetid://127837729576102", weight = 10 },
	},
	jog = {
		{ id = "rbxassetid://115879642640033", weight = 10 },
	},
	run = {
		{ id = "rbxassetid://86787802794828", weight = 10 },
	},
	swim = {
		{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 },
	},
	swimidle = {
		{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 },
	},
	jump = {
		{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 },
	},
	fall = {
		{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 },
	},
	climb = {
		{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 },
	},
	sit = {
		{ id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 },
	},
	toolnone = {
		{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 },
	},
	toolslash = {
		{ id = "http://www.roblox.com/asset/?id=522635514", weight = 10 },
	},
	toollunge = {
		{ id = "http://www.roblox.com/asset/?id=522638767", weight = 10 },
	},
	wave = {
		{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 },
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 },
	},
	dance = {
		{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 },
	},
	dance2 = {
		{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 },
	},
	dance3 = {
		{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 },
	},
	laugh = {
		{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 },
	},
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 },
	},
}

local DEFAULT_IDLE_FILE_LIST = AnimNames.idle
local DEFAULT_WALK_FILE_LIST = AnimNames.walk

local EmoteNames: { [string]: boolean } = {
	wave = false,
	point = false,
	dance = true,
	dance2 = true,
	dance3 = true,
	laugh = false,
	cheer = false,
}

math.randomseed(tick())

-- Helpers
local function IsActionLocked(): boolean
	return Character:GetAttribute("ActionLocked") == true
end

local function IsBlocking(): boolean
	return Character:GetAttribute("Blocking") == true
end

local function GetRigScale(): number
	if UserAnimateScaleRun then
		return Character:GetScale()
	end
	return 1
end

local function GetRunSpeed(): number
	local ModifiedRunSpeed = Character:GetAttribute("ModifiedRunSpeed")
	if typeof(ModifiedRunSpeed) == "number" and ModifiedRunSpeed > 0 then
		return ModifiedRunSpeed
	end

	local RunSpeed = Character:GetAttribute("RunSpeed")
	if typeof(RunSpeed) == "number" and RunSpeed > 0 then
		return RunSpeed
	end

	if Humanoid.WalkSpeed > 0 then
		return Humanoid.WalkSpeed
	end

	return CharacterBalance.Movement.WalkSpeed
end

local function ResolveAnimationId(AnimationIdOrKey: unknown): string?
	if typeof(AnimationIdOrKey) ~= "string" then
		return nil
	end

	if string.find(AnimationIdOrKey, "rbxassetid://") ~= nil then
		return AnimationIdOrKey
	end

	if string.find(AnimationIdOrKey, "http://") ~= nil or string.find(AnimationIdOrKey, "https://") ~= nil then
		return AnimationIdOrKey
	end

	local Resolved = AnimationDatabase[AnimationIdOrKey]
	if typeof(Resolved) == "string" then
		return Resolved
	end

	return nil
end

local function BuildSingleAnimationFileList(AnimationId: string): { FileListEntry }
	return {
		{ id = AnimationId, weight = 10 },
	}
end

local function ConfigureAnimationSet(Name: string, FileList: { FileListEntry })
	local NewSetTable: AnimSetTable = {
		count = 0,
		totalWeight = 0,
	}

	AnimTable[Name] = NewSetTable

	for Index, AnimDefinition in pairs(FileList) do
		local NewAnimation = Instance.new("Animation")
		NewAnimation.Name = Name
		NewAnimation.AnimationId = AnimDefinition.id

		NewSetTable[Index] = {
			anim = NewAnimation,
			weight = AnimDefinition.weight,
		}

		NewSetTable.count += 1
		NewSetTable.totalWeight += AnimDefinition.weight
	end

	for Index = 1, NewSetTable.count, 1 do
		local AnimationId = NewSetTable[Index].anim.AnimationId
		if PreloadedAnims[AnimationId] == nil then
			Animator:LoadAnimation(NewSetTable[Index].anim)
			PreloadedAnims[AnimationId] = true
		end
	end
end

local function StopLocomotion()
	if RunAnimTrack then
		RunAnimTrack:Stop(0.1)
		RunAnimTrack:Destroy()
		RunAnimTrack = nil
	end

	if JogAnimTrack then
		JogAnimTrack:Stop(0.1)
		JogAnimTrack:Destroy()
		JogAnimTrack = nil
	end

	if CurrentAnimTrack and (CurrentAnim == "walk" or CurrentAnim == "idle") then
		CurrentAnimTrack:Stop(0.1)
		CurrentAnimTrack:Destroy()
		CurrentAnimTrack = nil
	end
end

local function GetHeightScale(): number
	if not Humanoid then
		return GetRigScale()
	end

	if not Humanoid.AutomaticScalingEnabled then
		return GetRigScale()
	end

	local Scale = Humanoid.HipHeight / HUMANOID_HIP_HEIGHT
	Scale = 1 + (Humanoid.HipHeight - HUMANOID_HIP_HEIGHT) * SCALE_DAMPENING_PERCENT / HUMANOID_HIP_HEIGHT

	return Scale
end

local function GetMovementMode(): string
	local ModeValue = Character:GetAttribute("MovementMode")
	if ModeValue == "walk" or ModeValue == "jog" or ModeValue == "run" then
		return ModeValue
	end
	return "walk"
end

local function GetLocomotionAnimNameFromMode(ModeValue: string): string
	if ModeValue == "run" then
		return "run"
	end
	if ModeValue == "jog" then
		return "jog"
	end
	return "walk"
end

local function GetBaseLocomotionSpeedForMode(ModeValue: string): number
	local BaseRunSpeed = GetRunSpeed()
	local BaseWalkSpeed = CharacterBalance.Movement.WalkSpeed

	if ModeValue == "run" then
		return math.max(BaseRunSpeed, SMALL_BUT_NOT_ZERO)
	end

	if ModeValue == "jog" then
		return math.max(BaseRunSpeed, SMALL_BUT_NOT_ZERO)
	end

	return math.max(BaseWalkSpeed, SMALL_BUT_NOT_ZERO)
end

local function SetLocomotionSpeed(SpeedValue: number)
	local HeightScale = 1
	local ModeValue = GetMovementMode()

	local BaseSpeed = GetBaseLocomotionSpeedForMode(ModeValue)
	if BaseSpeed <= 0 then
		BaseSpeed = Humanoid.WalkSpeed
	end
	if BaseSpeed <= 0 then
		BaseSpeed = 1
	end

	local NormalizedSpeed = (SpeedValue / HeightScale) / BaseSpeed
	local ClampedSpeed = math.clamp(NormalizedSpeed, 0.05, 3)

	if CurrentAnimTrack then
		CurrentAnimTrack:AdjustWeight(1)
		CurrentAnimTrack:AdjustSpeed(ClampedSpeed)
	end
end

local function SetAnimationSpeed(SpeedValue: number)
	if CurrentAnim == "walk" then
		SetLocomotionSpeed(SpeedValue)
		return
	end

	if SpeedValue ~= CurrentAnimSpeed then
		CurrentAnimSpeed = SpeedValue
		if CurrentAnimTrack then
			CurrentAnimTrack:AdjustSpeed(CurrentAnimSpeed)
		end
	end
end

local function RollAnimation(AnimName: string): number
	local SetTable = AnimTable[AnimName]
	local Roll = math.random(1, SetTable.totalWeight)
	local Index = 1

	while Roll > SetTable[Index].weight do
		Roll -= SetTable[Index].weight
		Index += 1
	end

	return Index
end

local function KeyFrameReachedFunc(FrameName: string)
	if FrameName ~= "End" then
		return
	end

	if CurrentAnim == "walk" then
		if UserNoUpdateOnLoop == true then
			if RunAnimTrack and RunAnimTrack.Looped ~= true then
				RunAnimTrack.TimePosition = 0.0
			end
			if JogAnimTrack and JogAnimTrack.Looped ~= true then
				JogAnimTrack.TimePosition = 0.0
			end
			if CurrentAnimTrack and CurrentAnimTrack.Looped ~= true then
				CurrentAnimTrack.TimePosition = 0.0
			end
		else
			if RunAnimTrack then
				RunAnimTrack.TimePosition = 0.0
			end
			if JogAnimTrack then
				JogAnimTrack.TimePosition = 0.0
			end
			if CurrentAnimTrack then
				CurrentAnimTrack.TimePosition = 0.0
			end
		end
		return
	end

	local RepeatAnim = CurrentAnim
	if EmoteNames[RepeatAnim] ~= nil and EmoteNames[RepeatAnim] == false then
		RepeatAnim = "idle"
	end

	if CurrentlyPlayingEmote then
		if CurrentAnimTrack and CurrentAnimTrack.Looped then
			return
		end
		RepeatAnim = "idle"
		CurrentlyPlayingEmote = false
	end

	local AnimSpeed = CurrentAnimSpeed
	PlayAnimation(RepeatAnim, 0.1, Humanoid)
	SetAnimationSpeed(AnimSpeed)
end

function SwitchToAnim(Anim: Animation, AnimName: string, TransitionTime: number, _TargetHumanoid: Humanoid)
	if Anim == CurrentAnimInstance then
		return
	end

	if CurrentAnimTrack ~= nil then
		CurrentAnimTrack:Stop(TransitionTime)
		CurrentAnimTrack:Destroy()
	end

	if RunAnimTrack ~= nil then
		RunAnimTrack:Stop(TransitionTime)
		RunAnimTrack:Destroy()
		if UserNoUpdateOnLoop == true then
			RunAnimTrack = nil
		end
	end

	if JogAnimTrack ~= nil then
		JogAnimTrack:Stop(TransitionTime)
		JogAnimTrack:Destroy()
		JogAnimTrack = nil
	end

	CurrentAnimSpeed = 1.0

	local UpdatedCurrentAnimTrack = Animator:LoadAnimation(Anim)
	UpdatedCurrentAnimTrack.Priority = Enum.AnimationPriority.Core
	UpdatedCurrentAnimTrack:Play(TransitionTime)

	CurrentAnim = AnimName
	CurrentAnimInstance = Anim

	if CurrentAnimKeyframeHandler ~= nil then
		CurrentAnimKeyframeHandler:Disconnect()
	end
	CurrentAnimKeyframeHandler = UpdatedCurrentAnimTrack.KeyframeReached:Connect(KeyFrameReachedFunc)

	CurrentAnimTrack = UpdatedCurrentAnimTrack
end

function PlayAnimation(AnimName: string, TransitionTime: number, TargetHumanoid: Humanoid)
	local Index = RollAnimation(AnimName)
	local Anim = AnimTable[AnimName][Index].anim
	SwitchToAnim(Anim, AnimName, TransitionTime, TargetHumanoid)
	CurrentlyPlayingEmote = false
end

local function GetEquippedStyleName(): string?
	local EquippedItemId = Character:GetAttribute("EquippedItemId")
	if typeof(EquippedItemId) ~= "string" or EquippedItemId == "" then
		return nil
	end

	local ItemData = ItemDatabase.GetItem(EquippedItemId)
	if not ItemData or not ItemData.Style then
		return nil
	end

	return ItemData.Style
end

local function ApplyLocomotionAnimations()
	local IdleFileList = DEFAULT_IDLE_FILE_LIST
	local WalkFileList = DEFAULT_WALK_FILE_LIST

	if not IsBlocking() then
		local StyleName = GetEquippedStyleName()
		if StyleName then
			local IdleKeyOrId = StyleConfigModule.GetAnimation(StyleName, "Idle")
			local WalkKeyOrId = StyleConfigModule.GetAnimation(StyleName, "Walk")

			local ResolvedIdleId = ResolveAnimationId(IdleKeyOrId)
			local ResolvedWalkId = ResolveAnimationId(WalkKeyOrId)

			if ResolvedIdleId and ResolvedWalkId then
				IdleFileList = BuildSingleAnimationFileList(ResolvedIdleId)
				WalkFileList = BuildSingleAnimationFileList(ResolvedWalkId)
			end
		end
	end

	AnimNames.idle = IdleFileList
	AnimNames.walk = WalkFileList

	ConfigureAnimationSet("idle", AnimNames.idle)
	ConfigureAnimationSet("walk", AnimNames.walk)

	StopLocomotion()

	if IsActionLocked() then
		return
	end

	local SpeedValue = Humanoid.MoveDirection.Magnitude * Humanoid.WalkSpeed
	if SpeedValue > 0 then
		OnRunning(SpeedValue)
	else
		PlayAnimation("idle", 0.1, Humanoid)
		Pose = "Standing"
	end
end

function OnRunning(SpeedValue: number)
	if IsActionLocked() then
		return
	end

	local HeightScale = if UserAnimateScaleRun then GetHeightScale() else 1
	local MovedDuringEmote = CurrentlyPlayingEmote and Humanoid.MoveDirection == Vector3.new(0, 0, 0)
	local SpeedThreshold = MovedDuringEmote and (Humanoid.WalkSpeed / HeightScale) or 0.75

	if SpeedValue > SpeedThreshold * HeightScale then
		local ModeValue = GetMovementMode()
		local LocomotionAnimName = GetLocomotionAnimNameFromMode(ModeValue)

		Pose = "Running"
		PlayAnimation(LocomotionAnimName, MOVEMENT_TRANSITION_TIME, Humanoid)
		SetLocomotionSpeed(SpeedValue)
	else
		if EmoteNames[CurrentAnim] == nil and not CurrentlyPlayingEmote then
			PlayAnimation("idle", 0.2, Humanoid)
			Pose = "Standing"
		end
	end
end

function StopAllAnimations(): string
	local OldAnim = CurrentAnim

	if EmoteNames[OldAnim] ~= nil and EmoteNames[OldAnim] == false then
		OldAnim = "idle"
	end

	if CurrentlyPlayingEmote then
		OldAnim = "idle"
		CurrentlyPlayingEmote = false
	end

	CurrentAnim = ""
	CurrentAnimInstance = nil

	if CurrentAnimKeyframeHandler ~= nil then
		CurrentAnimKeyframeHandler:Disconnect()
		CurrentAnimKeyframeHandler = nil
	end

	if CurrentAnimTrack ~= nil then
		CurrentAnimTrack:Stop()
		CurrentAnimTrack:Destroy()
		CurrentAnimTrack = nil
	end

	if RunAnimTrack ~= nil then
		RunAnimTrack:Stop()
		RunAnimTrack:Destroy()
		RunAnimTrack = nil
	end

	if JogAnimTrack ~= nil then
		JogAnimTrack:Stop()
		JogAnimTrack:Destroy()
		JogAnimTrack = nil
	end

	return OldAnim
end

function OnDied()
	Pose = "Dead"
end

function OnJumping()
	PlayAnimation("jump", 0.1, Humanoid)
	JumpAnimTime = JUMP_ANIM_DURATION
	Pose = "Jumping"
end

function OnClimbing(SpeedValue: number)
	local AdjustedSpeed = SpeedValue
	if UserAnimateScaleRun then
		AdjustedSpeed /= GetHeightScale()
	end
	local Scale = 5.0
	PlayAnimation("climb", 0.1, Humanoid)
	SetAnimationSpeed(AdjustedSpeed / Scale)
	Pose = "Climbing"
end

function OnGettingUp()
	Pose = "GettingUp"
end

function OnFreeFall()
	if JumpAnimTime <= 0 then
		PlayAnimation("fall", FALL_TRANSITION_TIME, Humanoid)
	end
	Pose = "FreeFall"
end

function OnFallingDown()
	Pose = "FallingDown"
end

function OnSeated()
	Pose = "Seated"
end

function OnPlatformStanding()
	Pose = "PlatformStanding"
end

function OnSwimming(SpeedValue: number)
	local AdjustedSpeed = SpeedValue
	if UserAnimateScaleRun then
		AdjustedSpeed /= GetHeightScale()
	end

	if AdjustedSpeed > 1.00 then
		local Scale = 10.0
		PlayAnimation("swim", 0.4, Humanoid)
		SetAnimationSpeed(AdjustedSpeed / Scale)
		Pose = "Swimming"
	else
		PlayAnimation("swimidle", 0.4, Humanoid)
		Pose = "Standing"
	end
end

function StepAnimate(CurrentTime: number)
	if IsActionLocked() then
		return
	end

	local DeltaTime = CurrentTime - LastTick
	LastTick = CurrentTime

	if JumpAnimTime > 0 then
		JumpAnimTime -= DeltaTime
	end

	if Pose == "FreeFall" and JumpAnimTime <= 0 then
		PlayAnimation("fall", FALL_TRANSITION_TIME, Humanoid)
	elseif Pose == "Seated" then
		PlayAnimation("sit", 0.5, Humanoid)
		return
	elseif Pose == "Dead" or Pose == "GettingUp" or Pose == "FallingDown" or Pose == "PlatformStanding" then
		StopAllAnimations()
	end
end

-- Attribute wiring
Character:GetAttributeChangedSignal("ActionLocked"):Connect(function()
	local IsLocked = Character:GetAttribute("ActionLocked") == true

	if IsLocked then
		StopLocomotion()
	else
		local SpeedValue = Humanoid.MoveDirection.Magnitude * Humanoid.WalkSpeed
		if SpeedValue > 0 then
			OnRunning(SpeedValue)
		else
			PlayAnimation("idle", 0.2, Humanoid)
			Pose = "Standing"
		end
	end
end)

Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
	if IsActionLocked() then
		return
	end

	if Pose ~= "Running" then
		return
	end

	local SpeedValue = Humanoid.MoveDirection.Magnitude * Humanoid.WalkSpeed
	OnRunning(SpeedValue)
end)

Character:GetAttributeChangedSignal("EquippedItemId"):Connect(function()
	ApplyLocomotionAnimations()
end)

Character:GetAttributeChangedSignal("EquippedToolSlot"):Connect(function()
	ApplyLocomotionAnimations()
end)

Character:GetAttributeChangedSignal("Blocking"):Connect(function()
	ApplyLocomotionAnimations()
end)

-- Humanoid wiring
Humanoid.Died:Connect(OnDied)
Humanoid.Running:Connect(OnRunning)
Humanoid.Jumping:Connect(OnJumping)
Humanoid.Climbing:Connect(OnClimbing)
Humanoid.GettingUp:Connect(OnGettingUp)
Humanoid.FreeFalling:Connect(OnFreeFall)
Humanoid.FallingDown:Connect(OnFallingDown)
Humanoid.Seated:Connect(OnSeated)
Humanoid.PlatformStanding:Connect(OnPlatformStanding)
Humanoid.Swimming:Connect(OnSwimming)

Humanoid.Jumping:Connect(function(Jumped)
	if Jumped then
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		task.wait(JUMP_COOLDOWN_SECONDS)
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end)

-- Init
for Name, FileList in pairs(AnimNames) do
	ConfigureAnimationSet(Name, FileList)
end

ApplyLocomotionAnimations()

if Character.Parent ~= nil then
	PlayAnimation("idle", 0.1, Humanoid)
	Pose = "Standing"
end

-- Loop
while Character.Parent ~= nil do
	task.wait(0.1)
	StepAnimate(time())
end
