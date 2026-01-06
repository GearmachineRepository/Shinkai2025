--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationDatabase = require(Shared.Config.Data.AnimationDatabase)

export type PlayOptions = {
	FadeTime: number?,
	Speed: number?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
	Weight: number?,
}

export type AnimationReference = {
	AnimationId: string,
	AnimationName: string?,
}

type CharacterState = {
	Animator: Animator,
	Tracks: { [string]: AnimationTrack },
	Animations: { [string]: Animation },
	TrackSpeeds: { [AnimationTrack]: number },
}

local AnimationService = {}

local CharacterStates: { [Humanoid]: CharacterState } = {}

local DEFAULT_FADE_TIME = 0.15
local DEFAULT_SPEED = 1

local function GetHumanoidFromPlayer(Player: Player): Humanoid?
	local Character = Player.Character
	if not Character then
		return nil
	end

	return Character:FindFirstChildOfClass("Humanoid")
end

local function ResolveAnimationReference(AnimationKey: string): AnimationReference?
	if string.find(AnimationKey, "rbxassetid://") then
		return {
			AnimationId = AnimationKey,
			AnimationName = AnimationKey,
		}
	end

	if string.find(AnimationKey, "http://") or string.find(AnimationKey, "https://") then
		return {
			AnimationId = AnimationKey,
			AnimationName = AnimationKey,
		}
	end

	local ResolvedId = AnimationDatabase[AnimationKey]
	if typeof(ResolvedId) == "string" then
		return {
			AnimationId = ResolvedId,
			AnimationName = AnimationKey,
		}
	end

	return nil
end

local function GetOrCreateState(Humanoid: Humanoid): CharacterState
	local ExistingState = CharacterStates[Humanoid]
	if ExistingState then
		return ExistingState
	end

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		local NewAnimator = Instance.new("Animator")
		NewAnimator.Parent = Humanoid

		Animator = NewAnimator
	end

	local NewState = {
		Animator = Animator,
		Tracks = {},
		Animations = {},
		TrackSpeeds = {},
	} :: CharacterState

	CharacterStates[Humanoid] = NewState

	Humanoid.Destroying:Connect(function()
		CharacterStates[Humanoid] = nil
	end)

	return NewState
end

local function ApplyOptions(Track: AnimationTrack, Options: PlayOptions?, State: CharacterState)
	if not Options then
		return
	end

	if Options.Looped ~= nil then
		Track.Looped = Options.Looped
	end

	if Options.Priority ~= nil then
		Track.Priority = Options.Priority
	end

	if Options.Weight ~= nil then
		Track:AdjustWeight(Options.Weight, 0)
	end

	if Options.Speed ~= nil then
		Track:AdjustSpeed(Options.Speed)
		State.TrackSpeeds[Track] = Options.Speed
	end
end

local function GetOrLoadTrack(Humanoid: Humanoid, Reference: AnimationReference): AnimationTrack?
	local State = GetOrCreateState(Humanoid)

	local CachedTrack = State.Tracks[Reference.AnimationId]
	if CachedTrack then
		return CachedTrack
	end

	local AnimationObject = State.Animations[Reference.AnimationId]
	if not AnimationObject then
		local AnimationInstance = Instance.new("Animation")
		AnimationInstance.AnimationId = Reference.AnimationId
		AnimationInstance.Name = Reference.AnimationName or Reference.AnimationId

		State.Animations[Reference.AnimationId] = AnimationInstance
		AnimationObject = AnimationInstance
	end

	local NewTrack = State.Animator:LoadAnimation(AnimationObject)
	State.Tracks[Reference.AnimationId] = NewTrack
	return NewTrack
end

local function GetTrackByKey(Player: Player, AnimationKey: string): (AnimationTrack?, CharacterState?)
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return nil, nil
	end

	local State = CharacterStates[Humanoid]
	if not State then
		return nil, nil
	end

	local Reference = ResolveAnimationReference(AnimationKey)
	if not Reference then
		return nil, nil
	end

	local Track = State.Tracks[Reference.AnimationId]
	return Track, State
end

function AnimationService.Preload(Player: Player, Animations: { [string]: string })
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return
	end

	for _, AnimationKey in pairs(Animations) do
		local Reference = ResolveAnimationReference(AnimationKey)
		if Reference then
			GetOrLoadTrack(Humanoid, Reference)
		end
	end
end

function AnimationService.Play(Player: Player, AnimationKey: string, Options: PlayOptions?): AnimationTrack?
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return nil
	end

	local Reference = ResolveAnimationReference(AnimationKey)
	if not Reference then
		warn("Failed to resolve animation:", AnimationKey)
		return nil
	end

	local State = GetOrCreateState(Humanoid)
	local Track = GetOrLoadTrack(Humanoid, Reference)
	if not Track then
		return nil
	end

	ApplyOptions(Track, Options, State)
	Track:Play(Options and Options.FadeTime or DEFAULT_FADE_TIME)

	return Track
end

function AnimationService.Stop(Player: Player, AnimationKey: string, FadeTime: number?)
	local Track, _ = GetTrackByKey(Player, AnimationKey)
	if Track then
		Track:Stop(FadeTime or DEFAULT_FADE_TIME)
	end
end

function AnimationService.StopAll(Player: Player, FadeTime: number?)
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return
	end

	local State = CharacterStates[Humanoid]
	if not State then
		return
	end

	for _, Track in State.Tracks do
		Track:Stop(FadeTime or DEFAULT_FADE_TIME)
	end
end

function AnimationService.Pause(Player: Player, AnimationKey: string, Duration: number?)
	local Track, State = GetTrackByKey(Player, AnimationKey)
	if not Track or not State then
		return
	end

	local OriginalSpeed = State.TrackSpeeds[Track] or DEFAULT_SPEED
	Track:AdjustSpeed(0)

	if Duration and Duration > 0 then
		task.delay(Duration, function()
			if Track.IsPlaying then
				Track:AdjustSpeed(OriginalSpeed)
			end
		end)
	end
end

function AnimationService.Resume(Player: Player, AnimationKey: string)
	local Track, State = GetTrackByKey(Player, AnimationKey)
	if not Track or not State then
		return
	end

	local Speed = State.TrackSpeeds[Track] or DEFAULT_SPEED
	Track:AdjustSpeed(Speed)
end

function AnimationService.SetSpeed(Player: Player, AnimationKey: string, Speed: number)
	local Track, State = GetTrackByKey(Player, AnimationKey)
	if not Track or not State then
		return
	end

	Track:AdjustSpeed(Speed)
	State.TrackSpeeds[Track] = Speed
end

function AnimationService.GetSpeed(Player: Player, AnimationKey: string): number
	local Track, State = GetTrackByKey(Player, AnimationKey)
	if not Track or not State then
		return DEFAULT_SPEED
	end

	return State.TrackSpeeds[Track] or DEFAULT_SPEED
end

function AnimationService.IsPlaying(Player: Player, AnimationKey: string): boolean
	local Track, _ = GetTrackByKey(Player, AnimationKey)
	if not Track then
		return false
	end

	return Track.IsPlaying
end

function AnimationService.GetTrack(Player: Player, AnimationKey: string): AnimationTrack?
	local Track, _ = GetTrackByKey(Player, AnimationKey)
	return Track
end

return AnimationService