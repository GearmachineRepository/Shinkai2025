--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Server = ServerScriptService:WaitForChild("Server")

local Types = require(Server.Ensemble.Types)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnimationDatabase = require(Shared.Config.Data.AnimationDatabase)

type Entity = Types.Entity

export type PlayOptions = {
	FadeTime: number?,
	Speed: number?,
	Priority: Enum.AnimationPriority?,
	Looped: boolean?,
	Weight: number?,
}

local EntityAnimator = {}

local ActiveTracks: { [Model]: { [string]: AnimationTrack } } = {}

local DEFAULT_FADE_TIME = 0.15

local function GetAnimator(Character: Model): Animator?
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return nil
	end
	return Humanoid:FindFirstChildOfClass("Animator")
end

local function GetOrCreateTrackCache(Character: Model): { [string]: AnimationTrack }
	if not ActiveTracks[Character] then
		ActiveTracks[Character] = {}
	end
	return ActiveTracks[Character]
end

local function ResolveAnimationId(AnimationNameOrId: string): string?
	if string.find(AnimationNameOrId, "rbxassetid://") ~= nil then
		return AnimationNameOrId
	end

	if string.find(AnimationNameOrId, "http://") ~= nil or string.find(AnimationNameOrId, "https://") ~= nil then
		return AnimationNameOrId
	end

	local ResolvedId = AnimationDatabase[AnimationNameOrId]
	if typeof(ResolvedId) == "string" then
		return ResolvedId
	end

	return nil
end

local function LoadTrack(Animator: Animator, AnimationNameOrId: string): (AnimationTrack?, string?)
	local ResolvedAnimationId = ResolveAnimationId(AnimationNameOrId)
	if not ResolvedAnimationId then
		return nil, nil
	end

	local Animation = Instance.new("Animation")
	Animation.Name = AnimationNameOrId
	Animation.AnimationId = ResolvedAnimationId

	local Track = Animator:LoadAnimation(Animation)
	return Track, ResolvedAnimationId
end

function EntityAnimator.Play(Character: Model, AnimationNameOrId: string, Options: PlayOptions?): AnimationTrack?
	local Animator = GetAnimator(Character)
	if not Animator then
		return nil
	end

	local ResolvedAnimationId = ResolveAnimationId(AnimationNameOrId)
	if not ResolvedAnimationId then
		return nil
	end

	local Cache = GetOrCreateTrackCache(Character)
	local Track = Cache[ResolvedAnimationId]

	if not Track then
		local LoadedTrack, LoadedResolvedId = LoadTrack(Animator, AnimationNameOrId)
		if not LoadedTrack or not LoadedResolvedId then
			return nil
		end
		Track = LoadedTrack
		Cache[LoadedResolvedId] = Track
	end

	if Options then
		if Options.Speed then
			Track:AdjustSpeed(Options.Speed)
		end
		if Options.Priority then
			Track.Priority = Options.Priority
		end
		if Options.Looped ~= nil then
			Track.Looped = Options.Looped
		end
		if Options.Weight then
			Track:AdjustWeight(Options.Weight, 0)
		end
	end

	Track:Play(Options and Options.FadeTime or DEFAULT_FADE_TIME)
	return Track
end

function EntityAnimator.Stop(Character: Model, AnimationNameOrId: string, FadeTime: number?)
	local ResolvedAnimationId = ResolveAnimationId(AnimationNameOrId)
	if not ResolvedAnimationId then
		return
	end

	local Cache = ActiveTracks[Character]
	if not Cache then
		return
	end

	local Track = Cache[ResolvedAnimationId]
	if Track then
		Track:Stop(FadeTime or DEFAULT_FADE_TIME)
	end
end

function EntityAnimator.StopAll(Character: Model, FadeTime: number?)
	local Cache = ActiveTracks[Character]
	if not Cache then
		return
	end

	for _, Track in Cache do
		Track:Stop(FadeTime or DEFAULT_FADE_TIME)
	end
end

function EntityAnimator.Pause(Character: Model, AnimationNameOrId: string, Duration: number)
	local ResolvedAnimationId = ResolveAnimationId(AnimationNameOrId)
	if not ResolvedAnimationId then
		return
	end

	local Cache = ActiveTracks[Character]
	if not Cache then
		return
	end

	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		return
	end

	for _, Track in Animator:GetPlayingAnimationTracks() do
		if Track.Animation and Track.Animation.Name == AnimationNameOrId then
			Track:AdjustSpeed(0)
			task.delay(Duration, function()
				if Track.IsPlaying then
					Track:AdjustSpeed(1)
				end
			end)
			break
		end
	end
end

function EntityAnimator.Resume(Character: Model, AnimationNameOrId: string, Speed: number?)
	local ResolvedAnimationId = ResolveAnimationId(AnimationNameOrId)
	if not ResolvedAnimationId then
		return
	end

	local Cache = ActiveTracks[Character]
	if not Cache then
		return
	end

	local Track = Cache[ResolvedAnimationId]
	if Track then
		Track:AdjustSpeed(Speed or 1)
	end
end

function EntityAnimator.IsPlaying(Character: Model, AnimationNameOrId: string): boolean
	local ResolvedAnimationId = ResolveAnimationId(AnimationNameOrId)
	if not ResolvedAnimationId then
		return false
	end

	local Cache = ActiveTracks[Character]
	if not Cache then
		return false
	end

	local Track = Cache[ResolvedAnimationId]
	return Track and Track.IsPlaying == true
end

function EntityAnimator.Cleanup(Character: Model)
	local Cache = ActiveTracks[Character]
	if not Cache then
		return
	end

	for _, Track in Cache do
		Track:Stop(0)
		Track:Destroy()
	end

	ActiveTracks[Character] = nil
end

return EntityAnimator
