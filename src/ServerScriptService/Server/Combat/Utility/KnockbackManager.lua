--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")
local Shared = ReplicatedStorage:WaitForChild("Shared")

local Ensemble = require(Server.Ensemble)
local CombatEvents = require(script.Parent.Parent.CombatEvents)

local Packets = require(Shared.Networking.Packets)
local KnockbackBalance = require(Shared.Configurations.Balance.KnockbackBalance)

local KnockbackManager = {}

type KnockbackData = {
	BodyVelocity: BodyVelocity?,
	CleanupThread: thread?,
	ImpactCheckThread: thread?,
	Direction: Vector3,
	Speed: number,
	HasImpacted: boolean,
	StartTime: number,
	StartPosition: Vector3,
}

local ActiveKnockbacks: { [any]: KnockbackData } = {}

local IMPACT_CHECK_INTERVAL = 1 / 60
local IMPACT_RAY_DISTANCE = 3.25

local function GetFlatDirection(Direction: Vector3): Vector3
	local Flat = Vector3.new(Direction.X, 0, Direction.Z)
	if Flat.Magnitude < 0.001 then
		return Vector3.new(0, 0, -1)
	end
	return Flat.Unit
end

local function CreateRaycastParams(Character: Model): RaycastParams
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Character, workspace.Characters, workspace.Debris }
	Params.IgnoreWater = true
	return Params
end

local function CheckForImpact(Entity: any, KnockbackData: KnockbackData)
	if KnockbackData.HasImpacted then
		return
	end

	local Character = Entity.Character
	if not Character then
		return
	end

	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return
	end

    local RayParams = CreateRaycastParams(Character)
    local RayOrigin = RootPart.Position
    local RayDirection = KnockbackData.Direction * IMPACT_RAY_DISTANCE

    local RayResult = workspace:Raycast(RayOrigin, RayDirection, RayParams)

	if RayResult and RayResult.Instance then
		KnockbackData.HasImpacted = true

		local IFrameDuration = KnockbackBalance.ImpactIFrameDuration or 0.3
		if IFrameDuration > 0 and Entity.States then
			Entity.States:SetState("Invulnerable", true)

			task.delay(IFrameDuration, function()
				if Entity.States then
					Entity.States:SetState("Invulnerable", false)
				end
			end)
		end

		Ensemble.Events.Publish(CombatEvents.KnockbackImpact, {
			Entity = Entity,
			ImpactPosition = RayResult.Position,
			ImpactNormal = RayResult.Normal,
			ImpactInstance = RayResult.Instance,
			KnockbackSpeed = KnockbackData.Speed,
			KnockbackDirection = KnockbackData.Direction,
		})
	end
end

local function StartImpactDetection(Entity: any, Data: KnockbackData, Duration: number)
	Data.ImpactCheckThread = task.spawn(function()
		local StartTime = os.clock()

		while os.clock() - StartTime < Duration do
			if Data.HasImpacted then
				break
			end

			CheckForImpact(Entity, Data)
			task.wait(IMPACT_CHECK_INTERVAL)
		end
	end)
end

local function CleanupKnockback(Entity: any)
	local Existing = ActiveKnockbacks[Entity]
	if not Existing then
		return
	end

	if Existing.CleanupThread then
		local CleanupStatus = coroutine.status(Existing.CleanupThread)
		if CleanupStatus == "suspended" then
			task.cancel(Existing.CleanupThread)
		end
	end

	if Existing.ImpactCheckThread then
		local ImpactStatus = coroutine.status(Existing.ImpactCheckThread)
		if ImpactStatus == "suspended" or ImpactStatus == "running" then
			task.cancel(Existing.ImpactCheckThread)
		end
	end

	if Existing.BodyVelocity and Existing.BodyVelocity.Parent then
		Existing.BodyVelocity:Destroy()
	end

	ActiveKnockbacks[Entity] = nil
end

function KnockbackManager.Apply(Target: any, Attacker: any, Speed: number?, Duration: number?)
	if not Target or not Target.Character then
		return
	end

	local TargetRootPart = Target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not TargetRootPart then
		return
	end

	local AttackerRootPart: BasePart? = nil
	if Attacker then
		if typeof(Attacker) == "Instance" then
			if Attacker:IsA("Model") then
				AttackerRootPart = Attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
			elseif Attacker:IsA("BasePart") then
				AttackerRootPart = Attacker
			end
		elseif Attacker.Character then
			AttackerRootPart = Attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
	end

	local KnockbackDirection: Vector3
	if AttackerRootPart then
		KnockbackDirection = GetFlatDirection(AttackerRootPart.CFrame.LookVector)
	else
		local ToTarget = TargetRootPart.Position - Vector3.zero
		KnockbackDirection = GetFlatDirection(ToTarget)
	end

	local VerticalComponent = KnockbackBalance.VerticalComponent or 0
	if VerticalComponent > 0 then
		KnockbackDirection = (KnockbackDirection + Vector3.new(0, VerticalComponent, 0)).Unit
	end

	CleanupKnockback(Target)

	local FinalSpeed = Speed or KnockbackBalance.DefaultSpeed
	local FinalDuration = Duration or KnockbackBalance.DefaultDuration

	local KnockbackInfo: KnockbackData = {
		BodyVelocity = nil :: any,
		CleanupThread = nil :: any,
		ImpactCheckThread = nil,
		Direction = KnockbackDirection,
		Speed = FinalSpeed,
		HasImpacted = false,
		StartTime = os.clock(),
		StartPosition = TargetRootPart.Position,
	}

	if Target.Player then
		Packets.ApplyKnockback:FireClient(Target.Player, KnockbackDirection, FinalSpeed, FinalDuration)
	else
		local BodyVelocityInstance = Instance.new("BodyVelocity")
		BodyVelocityInstance.Name = "KnockbackVelocity"
		BodyVelocityInstance.MaxForce = Vector3.new(KnockbackBalance.MaxForce, 0, KnockbackBalance.MaxForce)
		BodyVelocityInstance.Velocity = KnockbackDirection * FinalSpeed
		BodyVelocityInstance.Parent = TargetRootPart
		KnockbackInfo.BodyVelocity = BodyVelocityInstance
	end

	KnockbackInfo.CleanupThread = task.delay(FinalDuration, function()
		if KnockbackInfo.BodyVelocity and KnockbackInfo.BodyVelocity.Parent then
			KnockbackInfo.BodyVelocity:Destroy()
		end
		ActiveKnockbacks[Target] = nil
	end)

	ActiveKnockbacks[Target] = KnockbackInfo

	Ensemble.Events.Publish(CombatEvents.KnockbackStarted, {
		Entity = Target,
		Attacker = Attacker,
		Direction = KnockbackDirection,
		Speed = FinalSpeed,
		Duration = FinalDuration,
	})

	StartImpactDetection(Target, KnockbackInfo, FinalDuration)
end

function KnockbackManager.Cancel(Entity: any)
	CleanupKnockback(Entity)
end

function KnockbackManager.IsActive(Entity: any): boolean
	return ActiveKnockbacks[Entity] ~= nil
end

function KnockbackManager.CleanupEntity(Entity: any)
	CleanupKnockback(Entity)
end

Packets.KnockbackImpact.OnServerEvent:Connect(function(Player: Player, ImpactPosition: Vector3, ImpactNormal: Vector3)
	if not Player.Character then return end

	local Entity = Ensemble.GetEntity(Player.Character :: Model)
	if not Entity then
		return
	end

	local KnockbackInfo = ActiveKnockbacks[Entity]
	if not KnockbackInfo or KnockbackInfo.HasImpacted then
		return
	end

	local RootPart = Player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not RootPart then
		return
	end

	local TimeElapsed = os.clock() - KnockbackInfo.StartTime
	local MaxTravelDistance = KnockbackInfo.Speed * TimeElapsed + 5
	local ClaimedDistance = (ImpactPosition - KnockbackInfo.StartPosition).Magnitude
	print(ClaimedDistance, MaxTravelDistance)
	if ClaimedDistance > MaxTravelDistance then
		return
	end

	-- local RayParams = RaycastParams.new()
	-- RayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- RayParams.FilterDescendantsInstances = { Player.Character, workspace.Characters, workspace.Debris }

	-- local RayOrigin = RootPart.Position
	-- local RayDirection = KnockbackInfo.Direction * 6
	-- local RayResult = workspace:Raycast(RayOrigin, RayDirection, RayParams)

	-- local Distance = RayDirection.Magnitude
    -- local DebugPart = Instance.new("Part")
    -- DebugPart.Anchored = true
    -- DebugPart.CanCollide = false
    -- DebugPart.Material = Enum.Material.Neon
    -- DebugPart.Parent = workspace.Debris
    -- DebugPart.CanQuery = false
    -- DebugPart.Size = Vector3.new(0.1, 0.1, Distance)
    -- DebugPart.CFrame = CFrame.lookAt(RayOrigin, RayOrigin + RayDirection) * CFrame.new(0, 0, -Distance / 2)
    -- game.Debris:AddItem(DebugPart, 2)

	-- if not RayResult then
	-- 	return
	-- end

	KnockbackInfo.HasImpacted = true

	local IFrameDuration = KnockbackBalance.ImpactIFrameDuration or 0.3
	if IFrameDuration > 0 and Entity.States then
		Entity.States:SetState("Invulnerable", true)
		task.delay(IFrameDuration, function()
			if Entity.States then
				Entity.States:SetState("Invulnerable", false)
			end
		end)
	end

	Ensemble.Events.Publish(CombatEvents.KnockbackImpact, {
		Entity = Entity,
		ImpactPosition = ImpactPosition,
		ImpactNormal = ImpactNormal,
		KnockbackSpeed = KnockbackInfo.Speed,
		KnockbackDirection = KnockbackInfo.Direction,
	})
end)

return KnockbackManager