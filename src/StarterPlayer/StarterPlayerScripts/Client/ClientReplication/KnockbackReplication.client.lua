--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packets = require(Shared.Networking.Packets)
local KnockbackBalance = require(Shared.Configurations.Balance.KnockbackBalance)

local Player = Players.LocalPlayer

local ActiveKnockback: {
	BodyVelocity: BodyVelocity,
	CleanupThread: thread,
}? = nil

local function GetRootPart(): BasePart?
	local Character = Player.Character
	if not Character then
		return nil
	end
	return Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function Cleanup()
	if not ActiveKnockback then
		return
	end

	if ActiveKnockback.CleanupThread then
		local Status = coroutine.status(ActiveKnockback.CleanupThread)
		if Status == "suspended" then
			task.cancel(ActiveKnockback.CleanupThread)
		end
	end

	if ActiveKnockback.BodyVelocity and ActiveKnockback.BodyVelocity.Parent then
		ActiveKnockback.BodyVelocity:Destroy()
	end

	ActiveKnockback = nil
end

Packets.ApplyKnockback.OnClientEvent:Connect(function(Direction: Vector3, Speed: number, Duration: number)
	local RootPart = GetRootPart()
	if not RootPart then
		return
	end

	Cleanup()
	local BodyVelocityInstance = Instance.new("BodyVelocity")
	BodyVelocityInstance.Name = "KnockbackVelocity"
	BodyVelocityInstance.MaxForce = Vector3.new(KnockbackBalance.MaxForce, 0, KnockbackBalance.MaxForce)
	BodyVelocityInstance.Velocity = Direction * Speed
	BodyVelocityInstance.Parent = RootPart

	local HasImpacted = false
	local Character = Player.Character

	task.spawn(function()
		local RayParams = RaycastParams.new()
		RayParams.FilterType = Enum.RaycastFilterType.Exclude
		RayParams.FilterDescendantsInstances = { Character }

		local StartTime = os.clock()
		while os.clock() - StartTime < Duration do
			if HasImpacted then
				break
			end

			local RayResult = workspace:Raycast(RootPart.Position, Direction * 2.5, RayParams)
			if RayResult then
				HasImpacted = true
				Packets.KnockbackImpact:Fire(RayResult.Position, RayResult.Normal)
				break
			end

			task.wait(1 / 60)
		end
	end)

	local CleanupThread = task.delay(Duration, function()
		if BodyVelocityInstance and BodyVelocityInstance.Parent then
			BodyVelocityInstance:Destroy()
		end
		HasImpacted = true
		ActiveKnockback = nil
	end)

	ActiveKnockback = {
		BodyVelocity = BodyVelocityInstance,
		CleanupThread = CleanupThread,
	}
end)