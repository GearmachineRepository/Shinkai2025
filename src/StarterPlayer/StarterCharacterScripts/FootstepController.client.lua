--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local Maid = require(Shared.General.Maid)
local FootstepEngine = require(Shared.Footsteps.FootstepEngine)

local Player = Players.LocalPlayer

local FootstepController = {}
FootstepController.CharacterMaid = Maid.new()

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

	FootstepEngine.PlayFootstep(Character, MaterialName)

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then
		return
	end

	Packets.Footplanted:Fire(MaterialName, HumanoidRootPart.Position, Player.UserId)
end

function FootstepController:SetupAnimationTracking(Animator: Animator, Character: Model)
	local ActiveTrackMaids: {[AnimationTrack]: Maid.MaidSelf} = {}

	local AnimationPlayedConnection = Animator.AnimationPlayed:Connect(function(Track: AnimationTrack)
		local TrackMaid = Maid.new()

		local MarkerConnection = Track:GetMarkerReachedSignal("Footplant"):Connect(function()
			self:OnFootplant(Character)
		end)

		TrackMaid:GiveTask(MarkerConnection)

		ActiveTrackMaids[Track] = TrackMaid

		Track.Stopped:Once(function()
			if ActiveTrackMaids[Track] then
				ActiveTrackMaids[Track]:DoCleaning()
				ActiveTrackMaids[Track] = nil
			end
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

function FootstepController:OnReplicatedFootplant(MaterialName: string, _: Vector3, PlayerId: number)
	if PlayerId == Player.UserId then
		return
	end

	local OtherPlayer = Players:GetPlayerByUserId(PlayerId)
	if not OtherPlayer then
		return
	end

	local Character = OtherPlayer.Character
	if not Character then
		return
	end

	FootstepEngine.InitializeCharacter(Character)
	FootstepEngine.PlayFootstep(Character, MaterialName)
end

Packets.Footplanted.OnClientEvent:Connect(function(MaterialName: string, Position: Vector3, PlayerId: number)
	FootstepController:OnReplicatedFootplant(MaterialName, Position, PlayerId)
end)

if Player.Character then
	FootstepController:SetupCharacter(Player.Character)
end

Player.CharacterAdded:Connect(function(Character: Model)
	FootstepController:SetupCharacter(Character)
end)