--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ProgressionSystem = require(Server.Systems.ProgressionSystem)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local Maid = require(Shared.General.Maid)



local BodyFatigueController = {}
BodyFatigueController.__index = BodyFatigueController

export type BodyFatigueController = typeof(setmetatable({} :: {
	Controller: any,
	PlayerData: any,
	Maid: Maid.MaidSelf,
}, BodyFatigueController))

function BodyFatigueController.new(CharacterController: any, PlayerData: any): BodyFatigueController
	local self = setmetatable({
		Controller = CharacterController,
		PlayerData = PlayerData,
		Maid = Maid.new(),
	}, BodyFatigueController)

	return self
end

function BodyFatigueController:Update(DeltaTime: number)
	ProgressionSystem.ProcessHunger(self.PlayerData, DeltaTime, self.Controller)
	ProgressionSystem.ProcessFat(self.PlayerData, DeltaTime, self.Controller)
end
function BodyFatigueController:AddFatigueFromStatGain(FatigueGain: number)
	local CurrentFatigue = self.Controller.StatManager:GetStat(StatTypes.BODY_FATIGUE)
	local MaxFatigue = self.Controller.StatManager:GetStat(StatTypes.MAX_BODY_FATIGUE)

	local NewFatigue = math.min(MaxFatigue, CurrentFatigue + FatigueGain)

	self.Controller.StatManager:SetStat(StatTypes.BODY_FATIGUE, NewFatigue)
end

function BodyFatigueController:CanGainStats(): boolean
	local CanTrain, _ = ProgressionSystem.CanTrain(self.PlayerData)
	return CanTrain
end

function BodyFatigueController:GetStatGainMultiplier(): number
	local CurrentFatigue = self.PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = self.PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100
	local FatiguePercent = (CurrentFatigue / MaxFatigue) * 100

	if FatiguePercent >= 50 then
		return 0.5
	end

	return 1.0
end

function BodyFatigueController:GetStaminaDrainMultiplier(): number
	local CurrentFatigue = self.PlayerData.Stats[StatTypes.BODY_FATIGUE] or 0
	local MaxFatigue = self.PlayerData.Stats[StatTypes.MAX_BODY_FATIGUE] or 100
	local FatiguePercent = (CurrentFatigue / MaxFatigue) * 100

	if FatiguePercent >= 70 then
		return 1.5
	elseif FatiguePercent >= 50 then
		return 1.25
	end

	return 1.0
end

function BodyFatigueController:Rest()
	ProgressionSystem.RestoreFatigue(self.PlayerData)
	self.Controller.StatManager:SetStat(StatTypes.BODY_FATIGUE, 0)
end

function BodyFatigueController:Destroy()
	self.Maid:DoCleaning()
end

return BodyFatigueController