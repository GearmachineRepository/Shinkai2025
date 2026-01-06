--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ModeBalance = require(Shared.Config.Modes.ModeBalance)
local ModeData = require(Shared.Config.Data.ModeData)
local StatTypes = require(Shared.Config.Enums.StatTypes)

local RemovalMode = {}
RemovalMode.__index = RemovalMode

export type RemovalModeType = typeof(setmetatable({} :: {
	Controller: any,
	IsActive: boolean,
	RemovalPercent: number,
	ActiveMaid: any,
	StartTime: number,
}, RemovalMode))

function RemovalMode.new(Controller: any): RemovalModeType
	local self = setmetatable({
		Controller = Controller,
		IsActive = false,
		RemovalPercent = ModeBalance.Removal.TrainablePercent.StartPercent,
		ActiveMaid = nil,
		StartTime = 0,
	}, RemovalMode)

	return self
end

function RemovalMode:CanActivate(): (boolean, string?)
	if self.IsActive then
		return false, "Mode already active"
	end

	local PlayerData = self.Controller.StateManager:GetData()
	local CurrentStamina = PlayerData.Stats[StatTypes.STAMINA] or 0

	if CurrentStamina < 10 then
		return false, "Not enough stamina"
	end

	return true
end

function RemovalMode:Activate()
	local CanActivate, ErrorMessage = self:CanActivate()
	if not CanActivate then
		warn(ErrorMessage)
		return
	end

	self.IsActive = true
	self.StartTime = tick()

	self:ApplyStatBoosts()
	self:ApplyVisualEffects()
	self:StartDurationTimer()
end

function RemovalMode:ApplyStatBoosts()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Removal
	local RemovalPercent = self.RemovalPercent :: number

	local PercentMultiplier = RemovalPercent / 100

	for StatName, StarBoost: number in pairs(Config.StatBoosts) do
		local ScaledBoost = StarBoost * PercentMultiplier
		PlayerData.Stats[StatName] = (PlayerData.Stats[StatName] or 0) + ScaledBoost
	end

	local HealthBoost = (PlayerData.Stats[StatTypes.MAX_HEALTH] or 100) * (Config.Bonuses.HealthBoostPercent / 100)
	PlayerData.Stats[StatTypes.HEALTH] += HealthBoost

	local StaminaBoost = (PlayerData.Stats[StatTypes.MAX_STAMINA] or 75) * (Config.Bonuses.StaminaBoostPercent / 100)
	PlayerData.Stats[StatTypes.STAMINA] += StaminaBoost
end

function RemovalMode:ApplyVisualEffects()
	local Character = self.Controller.Character
	local VisualConfig = ModeData.Definitions.Removal.VisualEffects

	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
			Part.Color = VisualConfig.SkinColor
		end
	end
end

function RemovalMode:StartDurationTimer()
	task.delay(ModeBalance.Removal.Duration, function()
		if self.IsActive then
			self:Deactivate()
		end
	end)
end

function RemovalMode:Deactivate()
	if not self.IsActive then
		return
	end

	self.IsActive = false

	self:RemoveStatBoosts()
	self:RemoveVisualEffects()

	if self.ActiveMaid then
		self.ActiveMaid:DoCleaning()
	end
end

function RemovalMode:RemoveStatBoosts()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Removal
	local RemovalPercent = self.RemovalPercent :: number

	local PercentMultiplier = RemovalPercent / 100

	for StatName, StarBoost: number in pairs(Config.StatBoosts) do
		local ScaledBoost = StarBoost * PercentMultiplier
		PlayerData.Stats[StatName] = (PlayerData.Stats[StatName] or 0) - ScaledBoost
	end
end

function RemovalMode:RemoveVisualEffects()
	local Character = self.Controller.Character

	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
			Part.Color = Color3.fromRGB(255, 255, 255)
		end
	end
end

function RemovalMode:TrainRemoval(AmountGained: number)
	local Config = ModeBalance.Removal.TrainablePercent
	local MaxPercent = Config.MaxPercentRegular
	local RemovalPercent = self.RemovalPercent :: number

	local ClanName = self.Controller.StateManager:GetData().Clan.ClanName
	if ClanName == "Wu" then
		MaxPercent = Config.MaxPercentWu
	end

	self.RemovalPercent = math.min(MaxPercent, RemovalPercent + AmountGained)
end

function RemovalMode:Destroy()
	self:Deactivate()
end

return RemovalMode