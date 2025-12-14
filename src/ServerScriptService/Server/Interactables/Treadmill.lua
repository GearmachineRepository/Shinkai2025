--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = ReplicatedStorage:WaitForChild("Assets")

local CharacterController = require(Server.Entity.Core.CharacterController)
local InteractableBase = require(Server.Interactables.InteractableBase)
local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local UpdateService = require(Shared.Networking.UpdateService)
local Packets = require(Shared.Networking.Packets)

export type InteractableModule = {
	OnInteract: (Player: Player, TreadmillModel: Model) -> (),
	OnStopInteract: (Player: Player, TreadmillModel: Model) -> (),
}

local TREADMILL_JOGGING_SPEED = 3.5
local TREADMILL_SPRINTING_SPEED = 4.5
local WELD_NAME = "TreadmillWeld"
local TRAINING_ATTRIBUTE = "Training"
local TREADMILL_MODE_ATTRIBUTE = "TreadmillMode"
local MOVEMENT_MODE_ATTRIBUTE = "MovementMode"

local UPDATE_RATE_SECONDS = 0.10

local TreadmillInteractable = {} :: InteractableModule

local ActiveTrainers: { [Player]: InteractableBase.ActiveUser } = {}

local function CleanupTreadmillEffects(Player: Player, TreadmillModel: Model)
	Packets.StopAnimation:FireClient(Player)

	local PrimaryPart = TreadmillModel.PrimaryPart
	if not PrimaryPart then
		return
	end

	local TreadmillSound = PrimaryPart:FindFirstChildWhichIsA("Sound")
	if TreadmillSound then
		TreadmillSound:Stop()
		TreadmillSound:Destroy()
	end

	local Tread = TreadmillModel:FindFirstChild("Tread") :: BasePart?
	if Tread then
		local TreadBeam = Tread:FindFirstChildOfClass("Beam")
		if TreadBeam then
			TreadBeam.TextureSpeed = 0
		end
	end
end

local function ExitTreadmill(PlayerWhoTrained: Player, TreadmillModel: Model)
	if not ActiveTrainers[PlayerWhoTrained] then
		return
	end

	local Character = PlayerWhoTrained.Character
	if Character then
		InteractableBase.RemoveWeld(Character, WELD_NAME)
		Character:SetAttribute(TRAINING_ATTRIBUTE, false)
		Character:SetAttribute(TREADMILL_MODE_ATTRIBUTE, nil)
		Character:SetAttribute(MOVEMENT_MODE_ATTRIBUTE, "walk")
	end

	CleanupTreadmillEffects(PlayerWhoTrained, TreadmillModel)
	InteractableBase.CleanupActiveUsers(PlayerWhoTrained, ActiveTrainers)
	InteractableBase.ReleaseInteractable(TreadmillModel)
end

local function UpdateTreadmillVisuals(TreadmillModel: Model, StatToTrain: string, Controller: any)
	local Tread = TreadmillModel:FindFirstChild("Tread") :: BasePart?
	if not Tread then
		return
	end

	local BaseSpeed = if StatToTrain == StatTypes.MAX_STAMINA
		then TREADMILL_JOGGING_SPEED
		else TREADMILL_SPRINTING_SPEED
	local RunSpeedStat = Controller.StatManager:GetStat(StatTypes.RUN_SPEED)

	local TreadSpeed = BaseSpeed * (1 + (RunSpeedStat * 0.1))

	local TreadBeam = Tread:FindFirstChildOfClass("Beam")
	if TreadBeam then
		TreadBeam.TextureSpeed = TreadSpeed
	end
end

local function StartTraining(Player: Player, TreadmillModel: Model, TrainingMode: string)
	local Character = Player.Character
	if not Character then
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller or not Controller.TrainingController then
		return
	end

	local TrainingController = Controller.TrainingController
	local StaminaController = Controller.StaminaController

	if not TrainingController:CanTrain() then
		ExitTreadmill(Player, TreadmillModel)
		return
	end

	Character:SetAttribute(TREADMILL_MODE_ATTRIBUTE, TrainingMode)

	local PrimaryPart = TreadmillModel.PrimaryPart
	if PrimaryPart then
		local TreadmillSound = Assets.Sounds.TreadmillRunning:Clone()
		TreadmillSound.Parent = PrimaryPart
		TreadmillSound:Play()
	end

	local AnimationName = if TrainingMode == "MaxStamina" then "jog" else "run"
	Packets.PlayAnimation:FireClient(Player, AnimationName)
	Character:SetAttribute(MOVEMENT_MODE_ATTRIBUTE, AnimationName)

	local TrainingConfig = if TrainingMode == "MaxStamina"
		then TrainingBalance.TrainingTypes.Stamina
		else TrainingBalance.TrainingTypes.RunSpeed

	local StatToTrain = if TrainingMode == "MaxStamina" then StatTypes.MAX_STAMINA else StatTypes.RUN_SPEED

	local VisualAccumulator = 0.0
	local StaminaAccumulator = 0.0
	local XpAccumulator = 0.0

	local PendingStaminaCost = 0.0
	local PendingXpGain = 0.0

	local TrainingConnection = UpdateService.RegisterWithCleanup(function(DeltaTime: number)
		if not Character.Parent then
			ExitTreadmill(Player, TreadmillModel)
			return
		end

		if not TrainingController:CanTrain() then
			ExitTreadmill(Player, TreadmillModel)
			return
		end

		VisualAccumulator += DeltaTime
		StaminaAccumulator += DeltaTime
		XpAccumulator += DeltaTime

		PendingStaminaCost += TrainingConfig.StaminaDrain * DeltaTime
		PendingXpGain += TrainingConfig.BaseXPPerSecond * DeltaTime

		if VisualAccumulator >= UPDATE_RATE_SECONDS then
			VisualAccumulator = 0
			UpdateTreadmillVisuals(TreadmillModel, StatToTrain, Controller)
		end

		if StaminaAccumulator >= UPDATE_RATE_SECONDS then
			StaminaAccumulator = 0

			if StaminaController then
				local Success = StaminaController:ConsumeStamina(PendingStaminaCost)
				PendingStaminaCost = 0

				if not Success then
					ExitTreadmill(Player, TreadmillModel)
					return
				end
			else
				PendingStaminaCost = 0
			end
		end

		if XpAccumulator >= UPDATE_RATE_SECONDS then
			XpAccumulator = 0

			TrainingController:GrantStatGain(StatToTrain, PendingXpGain)
			PendingXpGain = 0
		end
	end, 0.10)

	local ActiveUser = ActiveTrainers[Player]
	if ActiveUser then
		if ActiveUser.ActivityConnection then
			ActiveUser.ActivityConnection:Disconnect()
		end
		ActiveUser.ActivityConnection = TrainingConnection
	end
end

function TreadmillInteractable.OnInteract(Player: Player, TreadmillModel: Model)
	local IsValid, ErrorMessage = InteractableBase.ValidateBasicRequirements(Player)
	if not IsValid then
		warn(ErrorMessage)
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	local Controller = CharacterController.Get(Character)
	if not Controller or not Controller.TrainingController then
		return
	end

	if not Controller.TrainingController:CanTrain() then
		return
	end

	if ActiveTrainers[Player] then
		return
	end

	if not InteractableBase.ClaimInteractable(TreadmillModel, Player) then
		return
	end

	local TrainingLocation = TreadmillModel:FindFirstChild("TrainingLocation") :: BasePart?
	if not TrainingLocation then
		InteractableBase.ReleaseInteractable(TreadmillModel)
		return
	end

	local Weld = InteractableBase.WeldToInteractable(Character, TrainingLocation, WELD_NAME)
	if not Weld then
		InteractableBase.ReleaseInteractable(TreadmillModel)
		return
	end

	Character:SetAttribute(TRAINING_ATTRIBUTE, true)

	local JumpConnection = InteractableBase.SetupJumpExit(Character, function()
		ExitTreadmill(Player, TreadmillModel)
	end)

	ActiveTrainers[Player] = {
		Connection = JumpConnection,
		ActivityConnection = nil,
	}

	Packets.TreadmillModeSelected:FireClient(Player)
end

function TreadmillInteractable.OnStopInteract(Player: Player, TreadmillModel: Model)
	local CurrentTrainer = TreadmillModel:GetAttribute("ActiveFor")
	if CurrentTrainer == Player.UserId then
		ExitTreadmill(Player, TreadmillModel)
	end
end

Packets.SelectTreadmillMode.OnServerEvent:Connect(function(Player: Player, TrainingMode: string)
	if TrainingMode ~= "MaxStamina" and TrainingMode ~= "RunSpeed" then
		return
	end

	local Character = Player.Character
	if not Character then
		return
	end

	if not ActiveTrainers[Player] then
		return
	end

	for _, TreadmillModel in workspace:GetDescendants() do
		if TreadmillModel:IsA("Model") and TreadmillModel:GetAttribute("ActiveFor") == Player.UserId then
			StartTraining(Player, TreadmillModel, TrainingMode)
			break
		end
	end
end)

Players.PlayerRemoving:Connect(function(PlayerLeaving: Player)
	if ActiveTrainers[PlayerLeaving] then
		for _, TreadmillModel in workspace:GetDescendants() do
			if TreadmillModel:IsA("Model") and TreadmillModel:GetAttribute("ActiveFor") == PlayerLeaving.UserId then
				ExitTreadmill(PlayerLeaving, TreadmillModel)
				break
			end
		end
	end
end)

return TreadmillInteractable
