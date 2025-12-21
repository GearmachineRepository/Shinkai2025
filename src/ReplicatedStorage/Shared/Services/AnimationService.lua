--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationDatabase = require(Shared.Configurations.Data.AnimationDatabase)

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

local function ResolveAnimationId(AnimationKey: string): string?
	if string.find(AnimationKey, "rbxassetid://") == 1 then
		return AnimationKey
	end

	if tonumber(AnimationKey) then
		return "rbxassetid://" .. AnimationKey
	end

	for _AnimationName, AnimationId in pairs(AnimationDatabase) do
		if _AnimationName == AnimationKey then
			return AnimationId
		end
	end

	return nil
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

local function GetOrLoadTrack(Humanoid: Humanoid, AnimationId: string): AnimationTrack?
	local State = GetOrCreateState(Humanoid)

	local CachedTrack = State.Tracks[AnimationId]
	if CachedTrack then
		return CachedTrack
	end

	local AnimationObject = State.Animations[AnimationId]
	if not AnimationObject then
		local AnimationInstance = Instance.new("Animation")
		AnimationInstance.AnimationId = AnimationId

		State.Animations[AnimationId] = AnimationInstance

		AnimationObject = AnimationInstance
	end

	local NewTrack = State.Animator:LoadAnimation(AnimationObject)
	State.Tracks[AnimationId] = NewTrack
	return NewTrack
end

local AnimationService = {}

function AnimationService.Preload(Player: Player, Animations: { [string]: string })
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return
	end

	for _, AnimationKey in pairs(Animations) do
		local ResolvedId = ResolveAnimationId(AnimationKey)
		if ResolvedId then
			GetOrLoadTrack(Humanoid, ResolvedId)
		end
	end
end

function AnimationService.Play(Player: Player, AnimationKey: string, Options: PlayOptions?): AnimationTrack?
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return nil
	end

	local ResolvedId = ResolveAnimationId(AnimationKey)
	if not ResolvedId then
		warn("Failed to resolve animation:", AnimationKey)
		return nil
	end

	local Track = GetOrLoadTrack(Humanoid, ResolvedId)
	if not Track then
		return nil
	end

	ApplyOptions(Track, Options)
	Track:Play(Options and Options.FadeTime or DEFAULT_FADE_TIME)

	return Track
end

function AnimationService.Stop(Player: Player, AnimationKey: string, FadeTime: number?)
	local Humanoid = GetHumanoidFromPlayer(Player)
	if not Humanoid then
		return
	end

	local State = CharacterStates[Humanoid]
	if not State then
		return
	end

	local ResolvedId = ResolveAnimationId(AnimationKey)
	if not ResolvedId then
		return
	end

	local Track = State.Tracks[ResolvedId]
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