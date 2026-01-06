--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local ModeBalance = require(Shared.Config.Modes.ModeBalance)
local ModeData = require(Shared.Config.Data.ModeData)
local StatTypes = require(Shared.Config.Enums.StatTypes)

local AdvanceMode = {}
AdvanceMode.__index = AdvanceMode

export type AdvanceModeType = typeof(setmetatable({} :: {
	Controller: any,
	IsActive: boolean,
	ActiveMaid: any,
	StartTime: number,
}, AdvanceMode))

function AdvanceMode.new(Controller: any): AdvanceModeType
	local self = setmetatable({
		Controller = Controller,
		IsActive = false,
		ActiveMaid = nil,
		StartTime = 0,
	}, AdvanceMode)

	return self
end

function AdvanceMode:CanActivate(): (boolean, string?)
	if self.IsActive then
		return false, "Mode already active"
	end

	local PlayerData = self.Controller.StateManager:GetData()
	local CurrentStamina = PlayerData.Stats[StatTypes.STAMINA] or 0

	if CurrentStamina < 15 then
		return false, "Not enough stamina"
	end

	return true
end

function AdvanceMode:Activate()
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

function AdvanceMode:ApplyStatBoosts()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Advance

	for StatName, StarBoost in pairs(Config.StatBoosts) do
		PlayerData.Stats[StatName] = (PlayerData.Stats[StatName] or 0) + StarBoost
	end

	local StaminaBoost = (PlayerData.Stats[StatTypes.MAX_STAMINA] or 75) * (Config.Bonuses.StaminaBoostPercent / 100)
	PlayerData.Stats[StatTypes.STAMINA] += StaminaBoost
end

function AdvanceMode:ApplyVisualEffects()
	local Character = self.Controller.Character
	local VisualConfig = ModeData.Definitions.Advance.VisualEffects

	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
			Part.Color = VisualConfig.SkinColor
		end
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		local HeartbeatSound = Instance.new("Sound")
		HeartbeatSound.SoundId = VisualConfig.HeartbeatSound
		HeartbeatSound.Volume = VisualConfig.HeartbeatVolume
		HeartbeatSound.Looped = true
		HeartbeatSound.Parent = Character:FindFirstChild("HumanoidRootPart")
		HeartbeatSound:Play()
	end
end

function AdvanceMode:StartDurationTimer()
	task.delay(ModeBalance.Advance.Duration, function()
		if self.IsActive then
			self:Deactivate()
		end
	end)
end

function AdvanceMode:Deactivate()
	if not self.IsActive then
		return
	end

	self.IsActive = false

	self:RemoveStatBoosts()
	self:ApplyDamagePenalty()
	self:RemoveVisualEffects()

	if self.ActiveMaid then
		self.ActiveMaid:DoCleaning()
	end
end

function AdvanceMode:RemoveStatBoosts()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Advance

	for StatName, StarBoost in pairs(Config.StatBoosts) do
		PlayerData.Stats[StatName] = (PlayerData.Stats[StatName] or 0) - StarBoost
	end
end

function AdvanceMode:ApplyDamagePenalty()
	local PlayerData = self.Controller.StateManager:GetData()
	local Config = ModeBalance.Advance

	local CurrentHealth = PlayerData.Stats[StatTypes.HEALTH] or 0
	PlayerData.Stats[StatTypes.HEALTH] = math.max(1, CurrentHealth - Config.Penalties.DamageOnEnd)
end

function AdvanceMode:RemoveVisualEffects()
	local Character = self.Controller.Character

	for _, Part in Character:GetDescendants() do
		if Part:IsA("BasePart") and Part.Name ~= "HumanoidRootPart" then
			Part.Color = Color3.fromRGB(255, 255, 255)
		end
	end

	local HRP = Character:FindFirstChild("HumanoidRootPart")
	if HRP then
		local HeartbeatSound = HRP:FindFirstChildOfClass("Sound")
		if HeartbeatSound then
			HeartbeatSound:Stop()
			HeartbeatSound:Destroy()
		end
	end
end

function AdvanceMode:Destroy()
	self:Deactivate()
end

return AdvanceMode