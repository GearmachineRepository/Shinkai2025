--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)

local Player = Players.LocalPlayer

local ANIMATION_IDS = {
	jog = "rbxassetid://115879642640033",
	run = "rbxassetid://86787802794828",
	sleep = "rbxassetid://128741137506514",
}

local AnimationController = {}
AnimationController.Cache = {} :: { [string]: AnimationTrack }
AnimationController.CurrentTrack = nil :: AnimationTrack?
AnimationController.Character = nil :: Model?
AnimationController.Humanoid = nil :: Humanoid?

function AnimationController:Initialize(Character: Model)
	self.Character = Character
	self.Humanoid = Character:WaitForChild("Humanoid") :: Humanoid

	self:PreloadAllAnimations()
end

function AnimationController:PreloadAnimation(AnimationName: string, AnimationId: string): AnimationTrack?
	if not self.Humanoid then
		return nil
	end
	if not self.Humanoid:FindFirstChild("Animator") then
		return nil
	end

	local Animation = Instance.new("Animation")
	Animation.AnimationId = AnimationId

	local Success, Result = pcall(function()
		return self.Humanoid.Animator:LoadAnimation(Animation)
	end)

	if Success and Result then
		self.Cache[AnimationName] = Result
		return Result
	end

	return nil
end

function AnimationController:PreloadAllAnimations()
	for AnimationName, AnimationId in ANIMATION_IDS do
		self:PreloadAnimation(AnimationName, AnimationId)
	end
end

function AnimationController:Play(AnimationName: string)
	local Track = self.Cache[AnimationName]

	if not Track then
		return
	end

	if self.CurrentTrack and self.CurrentTrack.IsPlaying then
		self.CurrentTrack:Stop()
	end

	self.CurrentTrack = Track
	Track:Play()
end

function AnimationController:Stop()
	if self.CurrentTrack and self.CurrentTrack.IsPlaying then
		self.CurrentTrack:Stop()
		self.CurrentTrack = nil
	end
end

function AnimationController:Reset()
	for _, Track in self.Cache do
		if Track.IsPlaying then
			Track:Stop()
		end
		Track:Destroy()
	end

	table.clear(self.Cache)
	self.CurrentTrack = nil
end

function AnimationController:OnCharacterAdded(NewCharacter: Model)
	self:Reset()
	self:Initialize(NewCharacter)
end

Packets.PlayAnimation.OnClientEvent:Connect(function(AnimationName: string)
	AnimationController:Play(AnimationName)
end)

Packets.StopAnimation.OnClientEvent:Connect(function(_: string?)
	AnimationController:Stop()
end)

Player.CharacterAdded:Connect(function(NewCharacter: Model)
	AnimationController:OnCharacterAdded(NewCharacter)
end)

if Player.Character then
	AnimationController:Initialize(Player.Character)
end
