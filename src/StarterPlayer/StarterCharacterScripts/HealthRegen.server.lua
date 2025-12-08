--!strict

local Config = {
	HEALTH_REGEN_RATE = 1,
	HEALTH_REGEN_DELAY = 5,
	CHECK_INTERVAL = 0.1
}

local RunService = game:GetService("RunService")

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local lastDamageTime = 0

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

RunService.Heartbeat:Connect(function(deltaTime)
	if character:GetAttribute("InCombat") then return end
	if os.clock() - lastDamageTime < Config.HEALTH_REGEN_DELAY then return end

	local h = humanoid
	if h.Health >= h.MaxHealth then return end

	h.Health = math.min(h.MaxHealth, h.Health + Config.HEALTH_REGEN_RATE * deltaTime)
end)
