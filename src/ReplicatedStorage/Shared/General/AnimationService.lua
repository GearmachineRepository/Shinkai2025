--!strict

local DEFAULT_FADE_TIME = 0.1

export type PlayOptions = {
	FadeTime: number?,
	Weight: number?,
	Speed: number?,
	Looped: boolean?,
	Priority: Enum.AnimationPriority?,
}

type TrackCache = { [string]: AnimationTrack }
type AnimationCache = { [string]: Animation }

type CharacterState = {
	Animator: Animator,
	Tracks: TrackCache,
	Animations: AnimationCache,
}

local CharacterStates: { [Humanoid]: CharacterState } = {}

local function NormalizeAnimationId(AnimationId: string): string
	if string.find(AnimationId, "rbxassetid://") == 1 then
		return AnimationId
	end
	return "rbxassetid://" .. AnimationId
end

local function GetHumanoidFromPlayer(Player: Player): Humanoid?
	local Character = Player.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChildOfClass("Humanoid")
end

local function GetOrCreateAnimator(Humanoid: Humanoid): Animator
	local ExistingAnimator = Humanoid:FindFirstChildOfClass("Animator")
	if ExistingAnimator then
		return ExistingAnimator
	end

	local NewAnimator = Instance.new("Animator")
	NewAnimator.Parent = Humanoid
	return NewAnimator
end

local function GetOrCreateState(Humanoid: Humanoid): CharacterState
	local ExistingState = CharacterStates[Humanoid]
	if ExistingState then
		return ExistingState
	end

	local NewState: CharacterState = {
		Animator = GetOrCreateAnimator(Humanoid),
		Tracks = {},
		Animations = {},
	}

	CharacterStates[Humanoid] = NewState
	return NewState
end

local function ApplyOptions(Track: AnimationTrack, Options: PlayOptions?)
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
	end
end

local function GetOrLoadTrack(Humanoid: Humanoid, AnimationId: string): AnimationTrack
	local State = GetOrCreateState(Humanoid)
	local NormalizedId = NormalizeAnimationId(AnimationId)

	local CachedTrack = State.Tracks[NormalizedId]
	if CachedTrack then
		return CachedTrack
	end

	local AnimationObject = State.Animations[NormalizedId]
	if not AnimationObject then
		AnimationObject = Instance.new("Animation")
		AnimationObject.AnimationId = NormalizedId
		State.Animations[NormalizedId] = AnimationObject
	end

	local NewTrack = State.Animator:LoadAnimation(AnimationObject)
	State.Tracks[NormalizedId] = NewTrack
	return NewTrack
end

local AnimationService = {}

function AnimationService.Preload(Player: Player, Animations: { [string]: string })
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return
	end

	for _, AnimationId in pairs(Animations) do
		GetOrLoadTrack(Humanoid, AnimationId)
	end
end

function AnimationService.Play(Player: Player, AnimationId: string, Options: PlayOptions?): AnimationTrack?
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return nil
	end

	local Track = GetOrLoadTrack(Humanoid, AnimationId)
	ApplyOptions(Track, Options)

	Track:Play(Options and Options.FadeTime or DEFAULT_FADE_TIME)

	return Track
end

function AnimationService.Stop(Player: Player, AnimationId: string, FadeTime: number?)
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return
	end

	local State = CharacterStates[Humanoid]
	if not State then
		return
	end

	local NormalizedId = NormalizeAnimationId(AnimationId)
	local Track = State.Tracks[NormalizedId]
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

	for _, Track in pairs(State.Tracks) do
		Track:Stop(FadeTime or DEFAULT_FADE_TIME)
	end
end

return AnimationService
