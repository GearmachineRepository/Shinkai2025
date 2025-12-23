--!strict

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

type MarkerData = {
    Time: number,
    Value: string?,
}

type AnimationData = {
    Length: number,
    Markers: { [string]: MarkerData },
}

local AnimationTimingCache = {}

local Cache: { [string]: AnimationData } = {}
local Loading: { [string]: boolean } = {}

function AnimationTimingCache.GetMarkerTime(AnimationId: string, MarkerName: string): number?
    local Data = Cache[AnimationId]
    if Data and Data.Markers[MarkerName] then
        return Data.Markers[MarkerName].Time
    end
    return nil
end

function AnimationTimingCache.GetLength(AnimationId: string): number?
    local Data = Cache[AnimationId]
    return if Data then Data.Length else nil
end

function AnimationTimingCache.GetAllMarkers(AnimationId: string): { [string]: MarkerData }?
    local Data = Cache[AnimationId]
    return if Data then Data.Markers else nil
end

function AnimationTimingCache.IsLoaded(AnimationId: string): boolean
    return Cache[AnimationId] ~= nil
end

function AnimationTimingCache.PreloadAnimation(AnimationId: string): boolean
    if Cache[AnimationId] or Loading[AnimationId] then
        return Cache[AnimationId] ~= nil
    end

    Loading[AnimationId] = true

    local Success, Sequence = pcall(function()
        return KeyframeSequenceProvider:GetKeyframeSequenceAsync(AnimationId)
    end)

    Loading[AnimationId] = nil

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

    Cache[AnimationId] = {
        Length = MaxTime,
        Markers = Markers,
    }

    Sequence:Destroy()
    return true
end

function AnimationTimingCache.PreloadFolder(Folder: Instance)
    local Count = 0
    for _, Descendant in Folder:GetDescendants() do
        if Descendant:IsA("Animation") then
            if AnimationTimingCache.PreloadAnimation(Descendant.AnimationId) then
                Count += 1
            end
        end
    end
    return Count
end

function AnimationTimingCache.Clear()
    table.clear(Cache)
end

return AnimationTimingCache