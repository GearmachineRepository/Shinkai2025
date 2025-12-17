--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ModeBalance = require(Shared.Configurations.Balance.ModeBalance)
local StatTypes = require(Shared.Configurations.Enums.StatTypes)

local FlowMode = {}
FlowMode.__index = FlowMode

export type FlowModeType = typeof(setmetatable({} :: {
	Controller: any,
	IsActive: boolean,
	ActiveMaid: any,
	StartTime: number,
}, FlowMode))

function FlowMode.new(Controller: any): FlowModeType
	local self = setmetatable({
		Controller = Controller,
		IsActive = false,
		ActiveMaid = nil,
		StartTime = 0,
	}, FlowMode)

	return self
end

function FlowMode:CanActivate(): (boolean, string?)
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

function FlowMode:Activate()
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

function FlowMode:ApplyStatBoosts()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Flow

	for StatName, StarBoost in Config.StatBoosts do
		PlayerData.Stats[StatName] = (PlayerData.Stats[StatName] or 0) + StarBoost
	end

	local HealthBoost = (PlayerData.Stats[StatTypes.MAX_HEALTH] or 100) * (Config.Bonuses.HealthBoostPercent / 100)
	PlayerData.Stats[StatTypes.HEALTH] += HealthBoost

	local StaminaBoost = (PlayerData.Stats[StatTypes.MAX_STAMINA] or 75) * (Config.Bonuses.StaminaBoostPercent / 100)
	PlayerData.Stats[StatTypes.STAMINA] += StaminaBoost
end

function FlowMode:ApplyVisualEffects()
	local Character = self.Controller.Character

	local Head = Character:FindFirstChild("Head")
	if Head then
		local EyeGlow = Instance.new("PointLight")
		EyeGlow.Color = Color3.fromRGB(100, 150, 255)
		EyeGlow.Brightness = 2
		EyeGlow.Range = 8
		EyeGlow.Parent = Head
	end
end

function FlowMode:StartDurationTimer()
	task.delay(ModeBalance.Flow.Duration, function()
		if self.IsActive then
			self:Deactivate()
		end
	end)
end

function FlowMode:Deactivate()
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

function FlowMode:RemoveStatBoosts()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Flow

	for StatName, StarBoost in Config.StatBoosts do
		PlayerData.Stats[StatName] = (PlayerData.Stats[StatName] or 0) - StarBoost
	end
end

function FlowMode:RemoveVisualEffects()
	local Character = self.Controller.Character
	local Head = Character:FindFirstChild("Head")

	if Head then
		local EyeGlow = Head:FindFirstChildOfClass("PointLight")
		if EyeGlow then
			EyeGlow:Destroy()
		end
	end
end

function FlowMode:Destroy()
	self:Deactivate()
end

return FlowMode