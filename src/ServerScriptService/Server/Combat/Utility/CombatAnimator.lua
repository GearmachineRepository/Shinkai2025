--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local EnsembleTypes = require(script.Parent.Parent.Parent.Ensemble.Types)
local EntityAnimator = require(script.Parent.EntityAnimator)
local Packets = require(Shared.Networking.Packets)

type Entity = EnsembleTypes.Entity

local CombatAnimator = {}

function CombatAnimator.Play(Entity: Entity, AnimationId: string)
	if not AnimationId then
		return
	end

	if Entity.Player then
		Packets.PlayAnimation:FireClient(Entity.Player, AnimationId)
	elseif Entity.Character then
		EntityAnimator.Play(Entity.Character, AnimationId)
	end
end

function CombatAnimator.Stop(Entity: Entity, AnimationId: string, FadeTime: number?)
	if not AnimationId then
		return
	end

	local FinalFadeTime = FadeTime or 0.1

	if Entity.Player then
		Packets.StopAnimation:FireClient(Entity.Player, AnimationId, FinalFadeTime)
	elseif Entity.Character then
		EntityAnimator.Stop(Entity.Character, AnimationId, FinalFadeTime)
	end
end

function CombatAnimator.Pause(Entity: Entity, AnimationId: string, Duration: number?)
	if not AnimationId then
		return
	end

	if not Duration then return end

	if Entity.Player then
		Packets.PauseAnimation:FireClient(Entity.Player, AnimationId, Duration)
	elseif Entity.Character then
		EntityAnimator.Pause(Entity.Character, AnimationId, Duration)
	end
end

function CombatAnimator.Resume(Entity: Entity, AnimationId: string)
	if not AnimationId then
		return
	end

	if Entity.Player then
		Packets.ResumeAnimation:FireClient(Entity.Player, AnimationId)
	elseif Entity.Character then
		EntityAnimator.Resume(Entity.Character, AnimationId)
	end
end

function CombatAnimator.SetSpeed(Entity: Entity, AnimationId: string, Speed: number)
	if not AnimationId then
		return
	end

	if Entity.Player then
		Packets.SetAnimationSpeed:FireClient(Entity.Player, AnimationId, Speed)
	elseif Entity.Character then
		EntityAnimator.SetSpeed(Entity.Character, AnimationId, Speed)
	end
end

function CombatAnimator.StopAll(Entity: Entity, FadeTime: number?)
	local FinalFadeTime = FadeTime or 0.1

	if Entity.Player then
		Packets.StopAllAnimations:FireClient(Entity.Player, FinalFadeTime)
	elseif Entity.Character then
		EntityAnimator.StopAll(Entity.Character, FinalFadeTime)
	end
end

return CombatAnimator