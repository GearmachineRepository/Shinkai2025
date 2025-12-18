--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local Maid = require(Shared.General.Maid)
local FootstepEngine = require(Shared.Footsteps.FootstepEngine)
local FootstepMaterialMap = require(Shared.Footsteps.FootstepMaterialMap)

local Player = Players.LocalPlayer

local FootstepController = {}

FootstepController.CharacterMaid = Maid.new()
FootstepController.CurrentCharacter = nil :: Model?

function FootstepController:GetMaterialName(Character: Model): string?
	local Material = FootstepEngine.GetFloorMaterial(Character)

	if Material == Enum.Material.Air then
		return nil
	end

	return Material.Name
end

function FootstepController:OnFootplant(Character: Model)
	local MaterialName = self:GetMaterialName(Character)
	if not MaterialName then
		return
	end

	local MaterialId = FootstepMaterialMap.GetId(MaterialName)
	if not MaterialId then
		return
	end

	FootstepEngine.PlayFootstep(Character, MaterialId)
	Packets.Footplanted:Fire(MaterialId)
end

function FootstepController:SetupAnimationTracking(Animator: Animator, Character: Model)
	local ActiveTrackMaids: { [AnimationTrack]: Maid.MaidSelf } = {}

	local AnimationPlayedConnection = Animator.AnimationPlayed:Connect(function(Track: AnimationTrack)
		local TrackMaid = Maid.new()

		local MarkerConnection = Track:GetMarkerReachedSignal("Footplant"):Connect(function()
			self:OnFootplant(Character)
		end)

		TrackMaid:GiveTask(MarkerConnection)
		ActiveTrackMaids[Track] = TrackMaid

		Track.Stopped:Once(function()
			local ExistingTrackMaid = ActiveTrackMaids[Track]
			if not ExistingTrackMaid then
				return
			end

			ExistingTrackMaid:DoCleaning()
			ActiveTrackMaids[Track] = nil
		end)
	end)

	self.CharacterMaid:GiveTask(AnimationPlayedConnection)
	self.CharacterMaid:GiveTask(function()
		for _, TrackMaid in ActiveTrackMaids do
			TrackMaid:DoCleaning()
		end
		table.clear(ActiveTrackMaids)
	end)
end

function FootstepController:SetupCharacter(Character: Model)
	self.CharacterMaid:DoCleaning()
	self.CurrentCharacter = Character

	FootstepEngine.InitializeCharacter(Character)

	local Humanoid = Character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not Humanoid then
		warn("[FootstepController] No Humanoid found")
		return
	end

	local Animator = Humanoid:WaitForChild("Animator", 5) :: Animator?
	if not Animator then
		warn("[FootstepController] No Animator found")
		return
	end

	self:SetupAnimationTracking(Animator, Character)
end

function FootstepController:OnReplicatedFootplant(SenderUserId: number, MaterialId: number)
	if SenderUserId == Player.UserId then
		return
	end

	local OtherPlayer = Players:GetPlayerByUserId(SenderUserId)
	if not OtherPlayer then
		return
	end

	local Character = OtherPlayer.Character
	if not Character then
		return
	end

	FootstepEngine.InitializeCharacter(Character)
	FootstepEngine.PlayFootstep(Character, MaterialId)
end

Packets.FootplantedReplicate.OnClientEvent:Connect(function(SenderUserId: number, MaterialId: number)
	FootstepController:OnReplicatedFootplant(SenderUserId, MaterialId)
end)

Player.CharacterAdded:Connect(function(Character: Model)
	FootstepController:SetupCharacter(Character)
end)

if Player.Character then
	FootstepController:SetupCharacter(Player.Character)
end

return FootstepController
