--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Entity = require(Server.Framework.Core.Entity)
local InteractableBase = require(Server.Game.Interactables.InteractableBase)
local FatigueBalance = require(Shared.Configurations.Balance.FatigueBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Packets = require(Shared.Networking.Packets)
local UpdateService = require(Shared.Networking.UpdateService)

export type InteractableModule = {
	OnInteract: (Player: Player, BedModel: Model) -> (),
	OnStopInteract: (Player: Player, BedModel: Model) -> (),
}

local BedInteractable = {} :: InteractableModule

local ActiveSleepers: { [Player]: InteractableBase.ActiveUser } = {}

local WELD_NAME = "BedWeld"
local SLEEP_ATTRIBUTE = "Sleeping"

local function ExitBed(PlayerWhoSlept: Player, BedModel: Model)
	if not ActiveSleepers[PlayerWhoSlept] then
		return
	end

	local Character = PlayerWhoSlept.Character
	if Character then
		InteractableBase.RemoveWeld(Character, WELD_NAME)
		Character:SetAttribute(SLEEP_ATTRIBUTE, false)
	end

	Packets.StopAnimation:FireClient(PlayerWhoSlept, "Sleep", 0.25)

	InteractableBase.CleanupActiveUsers(PlayerWhoSlept, ActiveSleepers)
	InteractableBase.ReleaseInteractable(BedModel)
end

function BedInteractable.OnInteract(Player: Player, BedModel: Model)
	local IsValid, ErrorMessage = InteractableBase.ValidateBasicRequirements(Player)
	if not IsValid then
		warn(ErrorMessage)
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local EntityInstance = Entity.GetEntity(Character)
	if not EntityInstance then
		return
	end

	local SweatComponent = EntityInstance:GetComponent("Sweat")
	local BodyComponent = EntityInstance:GetComponent("BodyFatigue")

	if not SweatComponent or not BodyComponent then
		return
	end

	local ExistingFatigue = EntityInstance.Stats:GetStat(StatTypes.BODY_FATIGUE)
	if ExistingFatigue <= 0 then
		return
	end

	if ActiveSleepers[Player] then
		return
	end

	if not InteractableBase.ClaimInteractable(BedModel, Player) then
		return
	end

	local SleepLocation = BedModel:FindFirstChild("SleepLocation") :: BasePart
	if not SleepLocation then
		InteractableBase.ReleaseInteractable(BedModel)
		return
	end

	local Weld = InteractableBase.WeldToInteractable(Character, SleepLocation, WELD_NAME)
	if not Weld then
		InteractableBase.ReleaseInteractable(BedModel)
		return
	end

	Character:SetAttribute(SLEEP_ATTRIBUTE, true)

	local JumpConnection = InteractableBase.SetupJumpExit(Character, function()
		ExitBed(Player, BedModel)
	end)

	local MaxFatigue = EntityInstance.Stats:GetStat(StatTypes.MAX_BODY_FATIGUE)
	local ReductionRate = MaxFatigue / FatigueBalance.Rest.TIME_TO_FULL_REST

	Packets.PlayAnimation:FireClient(Player, "Sleep")

	local RestConnection = UpdateService.RegisterWithCleanup(function(DeltaTime: number)
		local CurrentFatigue = EntityInstance.Stats:GetStat(StatTypes.BODY_FATIGUE)

		if CurrentFatigue <= 0 then

			if SweatComponent then
				SweatComponent:StopSweating()
			end

			ExitBed(Player, BedModel)
			return
		end

		local FatigueReduction = ReductionRate * DeltaTime
		local NewFatigue = math.max(0, CurrentFatigue - FatigueReduction)

		EntityInstance.Stats:SetStat(StatTypes.BODY_FATIGUE, NewFatigue)
	end, 0.10) :: any

	ActiveSleepers[Player] = {
		Connection = JumpConnection,
		ActivityConnection = RestConnection,
	}
end

function BedInteractable.OnStopInteract(Player: Player, BedModel: Model)
	local CurrentSleeper = BedModel:GetAttribute("ActiveFor")
	if CurrentSleeper == Player.UserId then
		ExitBed(Player, BedModel)
	end
end

Players.PlayerRemoving:Connect(function(PlayerLeaving: Player)
	if ActiveSleepers[PlayerLeaving] then
		for _, BedModel in workspace:GetDescendants() do
			if BedModel:IsA("Model") and BedModel:GetAttribute("ActiveFor") == PlayerLeaving.UserId then
				ExitBed(PlayerLeaving, BedModel)
				break
			end
		end
	end
end)

return BedInteractable
