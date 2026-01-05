--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local AnimationService = require(Shared.Services.AnimationService)
local AnimationDatabase = require(Shared.Config.Data.AnimationDatabase)

local Player = Players.LocalPlayer

local function PreloadAllAnimations()
    local AllAnimations: { [any]: string } = {}

    for _AnimationName, AnimationId in pairs(AnimationDatabase) do
        table.insert(AllAnimations, AnimationId)
    end

    AnimationService.Preload(Player, AllAnimations)
end

Player.CharacterAdded:Connect(function()
    task.wait(0.1)
    PreloadAllAnimations()
end)

if Player.Character then
    PreloadAllAnimations()
end

Packets.PlayAnimation.OnClientEvent:Connect(function(AnimationId: string, Options: any?)
    AnimationService.Play(Player, AnimationId, Options)
end)

Packets.StopAnimation.OnClientEvent:Connect(function(AnimationId: string, FadeTime: number?)
    if AnimationId and AnimationId ~= "" then
        AnimationService.Stop(Player, AnimationId, FadeTime)
    else
        AnimationService.StopAll(Player, FadeTime)
    end
end)

Packets.PauseAnimation.OnClientEvent:Connect(function(AnimationId: string, Duration: number)
	local Humanoid = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	local Animator = Humanoid:FindFirstChildOfClass("Animator")
	if not Animator then
		return
	end

	for _, Track in Animator:GetPlayingAnimationTracks() do
		if Track.Animation and Track.Animation.Name == AnimationId then
			Track:AdjustSpeed(0)
			task.delay(Duration, function()
				if Track.IsPlaying then
					Track:AdjustSpeed(1)
				end
			end)
			break
		end
	end
end)