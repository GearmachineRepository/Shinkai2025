--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpdateService = require(Shared.Utility.UpdateService)
local Config = require(Shared.Config.Balance.CharacterBalance)

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local lastDamageTime = 0
local RUN_TIME_INTERVAL = 1 / 25

character:GetAttributeChangedSignal("InCombat"):Connect(function()
	if character:GetAttribute("InCombat") == false then
		lastDamageTime = os.clock()
	end
end)

local function NotifyDamageTaken()
	lastDamageTime = os.clock()
end

humanoid.HealthChanged:Connect(function(newHealth)
	if newHealth < humanoid.Health then
		NotifyDamageTaken()
	end
end)

UpdateService.Register(function(deltaTime)
	if character:GetAttribute("InCombat") then
		return
	end
	if os.clock() - lastDamageTime < Config.HealthRegen.Delay then
		return
	end

	local h = humanoid
	if h.Health >= h.MaxHealth then
		return
	end

	h.Health = math.min(h.MaxHealth, h.Health + Config.HealthRegen.Rate * deltaTime)
end, RUN_TIME_INTERVAL)
