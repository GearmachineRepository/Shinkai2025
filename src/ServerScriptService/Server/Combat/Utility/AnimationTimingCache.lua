--!strict

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

type MarkerData = {
	Time: number,
	Value: string?,
}

type AnimationData = {
	Length: number,
	Markers: { [string]: MarkerData },

	PrimaryName: string?,
	Names: { [string]: true },
	AnimationId: string,
}

local AnimationTimingCache = {}

local CacheByAnimationId: { [string]: AnimationData } = {}
local LoadingByAnimationId: { [string]: boolean } = {}

local AnimationIdByName: { [string]: string } = {}
local NamesByAnimationId: { [string]: { [string]: true } } = {}

local function RegisterName(AnimationName: string, AnimationId: string)
	if AnimationName == "" then
		return
	end

	AnimationIdByName[AnimationName] = AnimationId

	local ExistingNames = NamesByAnimationId[AnimationId]
	if ExistingNames == nil then
		ExistingNames = {}
		NamesByAnimationId[AnimationId] = ExistingNames
	end

	ExistingNames[AnimationName] = true

	local ExistingData = CacheByAnimationId[AnimationId]
	if ExistingData ~= nil then
		ExistingData.Names[AnimationName] = true
		if ExistingData.PrimaryName == nil then
			ExistingData.PrimaryName = AnimationName
		end
	end
end

local function ResolveAnimationId(AnimationNameOrId: string): string
	local AnimationId = AnimationIdByName[AnimationNameOrId]
	if AnimationId ~= nil then
		return AnimationId
	end

	return AnimationNameOrId
end

local function GetDataByNameOrId(AnimationNameOrId: string): AnimationData?
	local AnimationId = ResolveAnimationId(AnimationNameOrId)
	return CacheByAnimationId[AnimationId]
end

function AnimationTimingCache.GetMarkerTime(AnimationNameOrId: string, MarkerName: string, Speed: number?): number?
	local Data = GetDataByNameOrId(AnimationNameOrId)
	if Data and Data.Markers[MarkerName] then
		local RawTime = Data.Markers[MarkerName].Time
		local EffectiveSpeed = Speed or 1
		return RawTime / EffectiveSpeed
	end
	return nil
end

function AnimationTimingCache.GetLength(AnimationNameOrId: string, Speed: number?): number?
	local Data = GetDataByNameOrId(AnimationNameOrId)
	if Data then
		local EffectiveSpeed = Speed or 1
		return Data.Length / EffectiveSpeed
	end
	return nil
end

function AnimationTimingCache.GetAllMarkers(AnimationNameOrId: string): { [string]: MarkerData }?
	local Data = GetDataByNameOrId(AnimationNameOrId)
	return if Data then Data.Markers else nil
end

function AnimationTimingCache.IsLoaded(AnimationNameOrId: string): boolean
	local AnimationId = ResolveAnimationId(AnimationNameOrId)
	return CacheByAnimationId[AnimationId] ~= nil
end

function AnimationTimingCache.GetTiming(AnimationName: string, TimingName: string, FallbackValue: number?, Speed: number?): number?
	local EffectiveSpeed = Speed or 1
	local CachedTime = AnimationTimingCache.GetMarkerTime(AnimationName, TimingName)

	if CachedTime then
		return CachedTime / EffectiveSpeed
	end

	if typeof(FallbackValue) == "number" then
		return FallbackValue / EffectiveSpeed
	end

	return nil
end

function AnimationTimingCache.GetAnimationId(AnimationName: string): string?
	return AnimationIdByName[AnimationName]
end

function AnimationTimingCache.GetAnimationNames(AnimationNameOrId: string): { string }?
	local AnimationId = ResolveAnimationId(AnimationNameOrId)
	local NameSet = NamesByAnimationId[AnimationId]
	if NameSet == nil then
		return nil
	end

	local NameList: { string } = {}
	for Name in NameSet do
		table.insert(NameList, Name)
	end
	return NameList
end

function AnimationTimingCache.PreloadAnimation(AnimationId: string): boolean
	if CacheByAnimationId[AnimationId] or LoadingByAnimationId[AnimationId] then
		return CacheByAnimationId[AnimationId] ~= nil
	end

	LoadingByAnimationId[AnimationId] = true

	local Success, Sequence = pcall(function()
		return KeyframeSequenceProvider:GetKeyframeSequenceAsync(AnimationId)
	end)

	LoadingByAnimationId[AnimationId] = nil

	if not Success or not Sequence then
		warn("[Combat] Failed to load KeyframeSequence: " .. AnimationId)
		return false
	end

	local Markers: { [string]: MarkerData } = {}
	local MaxTime = 0

	for _, Keyframe in Sequence:GetKeyframes() do
		MaxTime = math.max(MaxTime, Keyframe.Time)

		for _, Marker in Keyframe:GetMarkers() do
			Markers[Marker.Name] = {
				Time = Keyframe.Time,
				Value = Marker.Value,
			}
		end
	end

	local NameSet = NamesByAnimationId[AnimationId] or {}

	CacheByAnimationId[AnimationId] = {
		AnimationId = AnimationId,
		Length = MaxTime,
		Markers = Markers,
		PrimaryName = next(NameSet) :: any,
		Names = NameSet,
	}

	Sequence:Destroy()
	return true
end

function AnimationTimingCache.PreloadFolder(Folder: Instance): number
	local Count = 0

	for _, Descendant in Folder:GetDescendants() do
		if Descendant:IsA("Animation") then
			local AnimationName = Descendant.Name
			local AnimationId = Descendant.AnimationId

			RegisterName(AnimationName, AnimationId)

			if AnimationTimingCache.PreloadAnimation(AnimationId) then
				Count += 1
			end
		end
	end

	return Count
end

function AnimationTimingCache.PreloadDatabase(Database: { [string]: string }): number
	local Count = 0

	for AnimationName, AnimationId in Database do
		if typeof(AnimationName) == "string" and typeof(AnimationId) == "string" then
			RegisterName(AnimationName, AnimationId)

			if AnimationTimingCache.PreloadAnimation(AnimationId) then
				Count += 1
			end
		end
	end

	return Count
end

function AnimationTimingCache.Clear()
	table.clear(CacheByAnimationId)
	table.clear(LoadingByAnimationId)
	table.clear(AnimationIdByName)
	table.clear(NamesByAnimationId)
end

return AnimationTimingCache