--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = ServerScriptService:WaitForChild("Server")
local Entity = Server:WaitForChild("Entity")

local StateManager = require(Entity.Core.StateManager)
local StatManager = require(Entity.Core.StatManager)
local HookController = require(Entity.Specialized.HookController)
local StateHandlers = require(Entity.Handlers.StateHandlers)

local StaminaController = require(Entity.PlayerControllers.StaminaController)
local HungerController = require(Entity.PlayerControllers.HungerController)
local BodyFatigueController = require(Entity.PlayerControllers.BodyFatigueController)
local TrainingController = require(Entity.PlayerControllers.TrainingController)
local BodyScalingController = require(Entity.PlayerControllers.BodyScalingController)
local SweatController = require(Entity.PlayerControllers.SweatController)

local TrainingBalance = require(Shared.Configurations.Balance.TrainingBalance)
local StatBalance = require(Shared.Configurations.Balance.StatBalance)
local CombatBalance = require(Shared.Configurations.Balance.CombatBalance)

local ModifierRegistry = require(Server.Entity.Registry.ModifierRegistry)
local ModifierConfigs = require(Shared.Configurations.Modifiers.BodyCompositionModifiers)

local StatTypes = require(Shared.Configurations.Enums.StatTypes)
local StateTypes = require(Shared.Configurations.Enums.StateTypes)
local Maid = require(Shared.General.Maid)

local CharacterController = {}
CharacterController.__index = CharacterController

export type DamageModifier = (Damage: number, Data: {[string]: any}) -> number
export type HealingModifier = (HealAmount: number, Data: {[string]: any}) -> number
export type StaminaCostModifier = (Cost: number, Data: {[string]: any}) -> number
export type SpeedModifier = (Speed: number, Data: {[string]: any}) -> number

export type ControllerType = typeof(setmetatable({} :: {
	Character: Model,
	Humanoid: Humanoid,
	IsPlayer: boolean,
	Player: Player?,
	Maid: Maid.MaidSelf,
	StateManager: StateManager.StateManager,
	StatManager: StatManager.StatManager,
	HookController: HookController.HookController,
	StaminaController: StaminaController.StaminaController?,
	HungerController: HungerController.HungerController?,
	BodyFatigueController: BodyFatigueController.BodyFatigueController?,
	TrainingController: TrainingController.TrainingController?,
	BodyScalingController: BodyScalingController.BodyScalingController?,
	SweatController: SweatController.SweatController?,
	ModifierRegistry: ModifierRegistry.ModifierRegistry,
}, CharacterController))

local Controllers: {[Model]: ControllerType} = {}

function CharacterController.new(Character: Model, Player: Player?, PlayerData: any?): ControllerType
	local self = setmetatable({
		Character = Character,
		Humanoid = Character:WaitForChild("Humanoid") :: Humanoid,
		IsPlayer = Player,
		Player = Player,
		Maid = Maid.new(),
		StateManager = nil :: StateManager.StateManager?,
		StatManager = nil :: StatManager.StatManager?,
		HookController = nil :: HookController.HookController?,
		StaminaController = nil,
		HungerController = nil,
		BodyFatigueController = nil,
		TrainingController = nil,
		BodyScalingController = nil,
		SweatController = nil,
		ModifierRegistry = ModifierRegistry.new(),
	}, CharacterController) :: ControllerType

	self.StateManager = StateManager.new(Character)
	self.StatManager = StatManager.new(Character, PlayerData)
	self.HookController = HookController.new(self)

	self.Maid:GiveTask(self.StateManager)
	self.Maid:GiveTask(self.StatManager)
	self.Maid:GiveTask(self.HookController)
	self.Maid:GiveTask(self.ModifierRegistry)

	Character:SetAttribute("HasController", true)
	Controllers[Character] = self

	StateHandlers.Setup(self)
	self:SetupHumanoidStateTracking()
	self:SetupBodyCompositionModifiers()

	if Player then
		self.BodyFatigueController = BodyFatigueController.new(self, PlayerData)
		self.StaminaController = StaminaController.new(self)
		self.HungerController = HungerController.new(self)
		self.TrainingController = TrainingController.new(self, PlayerData)
		self.BodyScalingController = BodyScalingController.new(self)
		self.SweatController = SweatController.new(self)

		self.Maid:GiveTask(self.BodyFatigueController)
		self.Maid:GiveTask(self.StaminaController)
		self.Maid:GiveTask(self.HungerController)
		self.Maid:GiveTask(self.TrainingController)
		self.Maid:GiveTask(self.BodyScalingController)
		self.Maid:GiveTask(self.SweatController)

		self:SetupMovementTracking()
		self:SetupStatChangeListeners()
	end

	self.Maid:GiveTask(self.Humanoid.Died:Connect(function()
		self:Destroy()
	end))

	return self
end

function CharacterController:SetupStatChangeListeners()
	self.Maid:GiveTask(self.StatManager:OnStatChanged(StatTypes.FAT, function()
		self:UpdateModifiedRunSpeed()
		if self.BodyScalingController then
			self.BodyScalingController:UpdateBodyScale()
		end
	end))

	self.Maid:GiveTask(self.StatManager:OnStatChanged(StatTypes.MUSCLE .. "_Stars", function()
		self:UpdateModifiedRunSpeed()
		if self.BodyScalingController then
			self.BodyScalingController:UpdateBodyScale()
		end
	end))

	self.Maid:GiveTask(self.StatManager:OnStatChanged(StatTypes.RUN_SPEED, function()
		self:UpdateModifiedRunSpeed()
	end))
end

function CharacterController:SetupHumanoidStateTracking()
	local Humanoid = self.Humanoid

	self.Maid:GiveTask(RunService.Heartbeat:Connect(function(DeltaTime)
		if self.BodyFatigueController then
			self.BodyFatigueController:Update(DeltaTime)
		end

		if self.HungerController then
			self.HungerController:Update()
		end

		if self.TrainingController then
			self.TrainingController:ProcessTraining(DeltaTime)
		end
	end))

	local IsInAir = false

	self.Maid:GiveTask(Humanoid.StateChanged:Connect(function(_, NewState)
		if NewState == Enum.HumanoidStateType.Jumping or NewState == Enum.HumanoidStateType.Freefall then
			if not IsInAir then
				IsInAir = true
				self.StateManager:SetState(StateTypes.JUMPING, true)
			end
		elseif NewState == Enum.HumanoidStateType.Landed or NewState == Enum.HumanoidStateType.Running then
			if IsInAir then
				IsInAir = false
				self.StateManager:SetState(StateTypes.JUMPING, false)
				self.StateManager:SetState(StateTypes.FALLING, false)
			end
		end

		if NewState == Enum.HumanoidStateType.Freefall then
			self.StateManager:SetState(StateTypes.FALLING, true)
		end
	end))
end

function CharacterController:GetExpectedWalkSpeed(MovementMode: string?): number
	local RunSpeedStat = self.StatManager:GetStat(StatTypes.RUN_SPEED)

	if MovementMode == "run" then
		return self.ModifierRegistry:Apply("Speed", RunSpeedStat)
	elseif MovementMode == "jog" then
		local JogSpeed = RunSpeedStat * StatBalance.MovementSpeeds.JogSpeedPercent
		return self.ModifierRegistry:Apply("Speed", JogSpeed)
	else
		return StatBalance.MovementSpeeds.WalkSpeed
	end
end

function CharacterController:SetupMovementTracking()
	if not self.Player or not self.StaminaController then
		return
	end

	-- Enforce WalkSpeed every frame (anti-exploit)
	self.Maid:GiveTask(RunService.Heartbeat:Connect(function()
		local CurrentMode = self.Character:GetAttribute("MovementMode")
		local ExpectedSpeed = self:GetExpectedWalkSpeed(CurrentMode)

		-- Only update if different to avoid unnecessary operations
		if math.abs(self.Humanoid.WalkSpeed - ExpectedSpeed) > 0.01 then
			self.Humanoid.WalkSpeed = ExpectedSpeed
		end
	end))

	self.Maid:GiveTask(self.Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		local CurrentMode = self.Character:GetAttribute("MovementMode")

		self.Maid:Set("MovementTraining", nil)

		if CurrentMode == "run" then
			self:HandleSprintMode()
		elseif CurrentMode == "jog" then
			self:HandleJogMode()
		else
			self:HandleWalkMode()
		end
	end))
end

function CharacterController:HandleSprintMode()
	self.StateManager:SetState(StateTypes.SPRINTING, true)
	self.StateManager:SetState(StateTypes.JOGGING, false)
	self.StateManager:FireEvent("SprintStarted", {})

	if self.StaminaController then
		self.StaminaController:OnSprintStart()
	end

	-- Speed is enforced by Heartbeat loop, just set it once
	self.Humanoid.WalkSpeed = self:GetExpectedWalkSpeed("run")

	local SprintConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		local IsMoving = self.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude > 1

		if IsMoving and self.StaminaController then
			local Success = self.StaminaController:HandleSprint(DeltaTime)

			if not Success then
				self.Character:SetAttribute("MovementMode", "walk")
				self.StateManager:SetState(StateTypes.SPRINTING, false)
				self.StateManager:FireEvent("SprintStopped", {})
				self.StateManager:FireEvent("StaminaDepleted", {})
			else
				if self.TrainingController and self.TrainingController:CanTrain() then
					local RunSpeedXP = (TrainingBalance.TrainingTypes.RunSpeed.BaseXPPerSecond * TrainingBalance.TrainingTypes.RunSpeed.NonmachineMultiplier) * DeltaTime
					local FatigueGain = 0.5 * 0.7
					self.TrainingController:GrantStatGain(StatTypes.RUN_SPEED, RunSpeedXP, FatigueGain)
				end
			end
		end
	end)

	self.Maid:Set("MovementTraining", SprintConnection)
end

function CharacterController:HandleJogMode()
	self.StateManager:SetState(StateTypes.JOGGING, true)
	self.StateManager:SetState(StateTypes.SPRINTING, false)
	self.StateManager:FireEvent("JogStarted", {})

	if self.StaminaController then
		self.StaminaController:OnJogStart()
	end

	-- Speed is enforced by Heartbeat loop, just set it once
	self.Humanoid.WalkSpeed = self:GetExpectedWalkSpeed("jog")

	local JogConnection = RunService.Heartbeat:Connect(function(DeltaTime)
		local IsMoving = self.Character.PrimaryPart.AssemblyLinearVelocity.Magnitude > 1

		if IsMoving and self.StaminaController then
			local Success = self.StaminaController:HandleJog(DeltaTime)

			if not Success then
				self.Character:SetAttribute("MovementMode", "walk")
				self.StateManager:SetState(StateTypes.JOGGING, false)
				self.StateManager:FireEvent("JogStopped", {})
				self.StateManager:FireEvent("StaminaDepleted", {})
			else
				if self.TrainingController and self.TrainingController:CanTrain() then
					local StaminaXP = (TrainingBalance.TrainingTypes.Stamina.BaseXPPerSecond * TrainingBalance.TrainingTypes.Stamina.NonmachineMultiplier) * DeltaTime
					local FatigueGain = 0.5 * 0.8
					self.TrainingController:GrantStatGain(StatTypes.MAX_STAMINA, StaminaXP, FatigueGain)
				end
			end
		end
	end)

	self.Maid:Set("MovementTraining", JogConnection)
end

function CharacterController:HandleWalkMode()
	local WasSprinting = self.StateManager:GetState(StateTypes.SPRINTING)
	local WasJogging = self.StateManager:GetState(StateTypes.JOGGING)

	if self.StaminaController then
		if WasSprinting then
			self.StaminaController:OnSprintEnd()
		end
		if WasJogging then
			self.StaminaController:OnJogEnd()
		end
	end

	if WasSprinting then
		self.StateManager:FireEvent("SprintStopped", {})
	end

	if WasJogging then
		self.StateManager:FireEvent("JogStopped", {})
	end

	self.StateManager:SetState(StateTypes.SPRINTING, false)
	self.StateManager:SetState(StateTypes.JOGGING, false)

	-- Speed is enforced by Heartbeat loop, just set it once
	self.Humanoid.WalkSpeed = 8
end

function CharacterController:TakeDamage(Damage: number, Source: Player?, Direction: Vector3?)
	local ModifiedDamage = self.ModifierRegistry:Apply("Damage", Damage, {
		Source = Source,
		Direction = Direction,
		OriginalDamage = Damage,
	})

	if self.StateManager:GetState(StateTypes.INVULNERABLE) then
		return
	end

	if self.StateManager:GetState(StateTypes.BLOCKING) then
		ModifiedDamage = ModifiedDamage * (1 - CombatBalance.Blocking.DAMAGE_REDUCTION)
	end

	self.Humanoid.Health -= ModifiedDamage

	self.StateManager:FireEvent("DamageTaken", {
		Amount = ModifiedDamage,
		Source = Source,
		Direction = Direction,
		WasBlocked = self.StateManager:GetState(StateTypes.BLOCKING),
		HealthPercent = self.Humanoid.Health / self.Humanoid.MaxHealth,
	})
end

function CharacterController:DealDamage(Target: Model, BaseDamage: number)
	local FinalDamage = self.ModifierRegistry:Apply("Attack", BaseDamage, {
		Target = Target,
	})

	local TargetController = CharacterController.Get(Target)
	if TargetController then
		TargetController:TakeDamage(FinalDamage, self.Player)
	end
end

function CharacterController:SetStates(StatesToSet: {[string]: boolean})
	for StateName, Value in StatesToSet do
		self.StateManager:SetState(StateName, Value)
	end
end

function CharacterController:UpdateMaxHealth()
	local BaseMaxHealth = StatBalance.Defaults.MaxHealth
	local FinalMaxHealth = self.ModifierRegistry:Apply("MaxHealth", BaseMaxHealth)

	self.StatManager:SetStat(StatTypes.MAX_HEALTH, FinalMaxHealth)

	local CurrentHealth = self.StatManager:GetStat(StatTypes.HEALTH)
	if CurrentHealth > FinalMaxHealth then
		self.StatManager:SetStat(StatTypes.HEALTH, FinalMaxHealth)
	end

	if self.Humanoid then
		self.Humanoid.MaxHealth = self.StatManager:GetStat(StatTypes.MAX_HEALTH)
		self.Humanoid.Health = self.StatManager:GetStat(StatTypes.HEALTH)
	end
end

function CharacterController:UpdateModifiedRunSpeed()
	local RunSpeedStat = self.StatManager:GetStat(StatTypes.RUN_SPEED)

	local ModifiedRunSpeed = self.ModifierRegistry:Apply("Speed", RunSpeedStat)

	self.Character:SetAttribute("ModifiedRunSpeed", ModifiedRunSpeed)
end

function CharacterController:SetupBodyCompositionModifiers()
    for _, Config in ModifierConfigs do
        self.ModifierRegistry:Register(Config.Type, Config.Priority, function(BaseValue, Data)
            return Config.Calculate(BaseValue, self.StatManager, Data)
        end)
    end

    -- Event listeners
	self.Maid:GiveTask(self.StatManager:OnStatChanged(StatTypes.FAT, function(_, _)
		self:UpdateMaxHealth()
	end))
end

function CharacterController:Destroy()
	self.Maid:DoCleaning()
	Controllers[self.Character] = nil
end

function CharacterController.Get(Character: Model): ControllerType?
	return Controllers[Character]
end


function CharacterController:GetDebugInfo(): {[string]: any}
	local ActiveStates = {}
	for StateName, _ in StateTypes do
		if self.StateManager:GetState(StateName) then
			table.insert(ActiveStates, StateName)
		end
	end

	local ActiveHooks = self.HookController:GetActiveHooks()

	return {
		CharacterName = self.Character.Name,
		IsPlayer = self.IsPlayer,
		Health = string.format("%.1f/%.1f", self.Humanoid.Health, self.Humanoid.MaxHealth),
		Stamina = string.format("%.1f/%.1f",
			self.StatManager:GetStat(StatTypes.STAMINA),
			self.StatManager:GetStat(StatTypes.MAX_STAMINA)
		),
		ActiveStates = ActiveStates,
		ActiveHooks = ActiveHooks,
		ModifierCounts = {
			Attack = self.ModifierRegistry:GetCount("Attack"),
			Damage = self.ModifierRegistry:GetCount("Damage"),
			Speed = self.ModifierRegistry:GetCount("Speed"),
			StrikeSpeed = self.ModifierRegistry:GetCount("StrikeSpeed"),
			Healing = self.ModifierRegistry:GetCount("Healing"),
			StaminaCost = self.ModifierRegistry:GetCount("StaminaCost"),
			MaxHealth = self.ModifierRegistry:GetCount("MaxHealth"),
		},
	}
end

return CharacterController