--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)
local Types = require(Server.Ensemble.Types)
local ActionExecutor = require(Server.Combat.ActionExecutor)

local NpcCombatComponent = {}
NpcCombatComponent.__index = NpcCombatComponent

NpcCombatComponent.ComponentName = "NpcCombat"
NpcCombatComponent.Dependencies = { "States" }
NpcCombatComponent.UpdateRate = 1/5

type CombatConfig = {
	ToolId: number?,
	AttackRange: number?,
	AggroRange: number?,
	AutoAttack: boolean?,
	AttackIntervalMin: number?,
	AttackIntervalMax: number?,
}

type Self = {
	Entity: Types.Entity,
	Maid: Types.Maid,
	ToolId: number,
	AttackRange: number,
	AggroRange: number,
	AutoAttack: boolean,
	AttackIntervalMin: number,
	AttackIntervalMax: number,
	Target: Types.Entity?,
	IsRunning: boolean,
}

function NpcCombatComponent.new(Entity: Types.Entity, Context: Types.EntityContext): Self
	local Config: CombatConfig = Context and Context.Combat or {}

    local self: Self = setmetatable({
        Entity = Entity,
        Maid = Ensemble.Maid.new(),
        ToolId = Config.ToolId or 1,
        AttackRange = Config.AttackRange or 6,
        AggroRange = Config.AggroRange or 30,
        AutoAttack = Config.AutoAttack or false,
        AttackIntervalMin = Config.AttackIntervalMin or 2.0,
        AttackIntervalMax = Config.AttackIntervalMax or 4.0,
        Target = nil,
        IsRunning = false,
        NextAttackTime = 0,
    }, NpcCombatComponent) :: any

	return self
end

function NpcCombatComponent:Update(DeltaTime: number)
	if not self.AutoAttack then
		return
	end

	if not self:CanAct() then
		return
	end

    local NextAttackTime = self.NextAttackTime :: number
	NextAttackTime -= DeltaTime
    self.NextAttackTime = NextAttackTime

	if self.NextAttackTime > 0 then
		return
	end

	local AttackIntervalMin = self.AttackIntervalMin :: number
	local AttackIntervalMax = self.AttackIntervalMax :: number

	local Interval =
		AttackIntervalMin
		+ math.random() * (AttackIntervalMax - AttackIntervalMin)

	self.NextAttackTime = Interval

	self:LightAttack()
end

function NpcCombatComponent:CanAct(): boolean
	if ActionExecutor.GetActiveContext(self.Entity) then
		return false
	end

	if self.Entity.States:GetState("Stunned") then
		return false
	end

	if self.Entity.States:GetState("Downed") then
		return false
	end

	if self.Entity.States:GetState("Ragdolled") then
		return false
	end

	return true
end

function NpcCombatComponent:LightAttack(): (boolean, string?)
	if not self:CanAct() then
		return false, "CannotAct"
	end

	local InputData = { ItemId = self.ToolId }
	return ActionExecutor.Execute(self.Entity, "LightAttack", "M1", InputData)
end

function NpcCombatComponent:HeavyAttack(): (boolean, string?)
	if not self:CanAct() then
		return false, "CannotAct"
	end

	local InputData = { ItemId = self.ToolId }
	return ActionExecutor.Execute(self.Entity, "HeavyAttack", "M2", InputData)
end

function NpcCombatComponent:Block(): (boolean, string?)
	if not self:CanAct() then
		return false, "CannotAct"
	end

	local InputData = { ItemId = self.ToolId }
	return ActionExecutor.Execute(self.Entity, "Block", "Block", InputData)
end

function NpcCombatComponent:StopBlocking(): boolean
	local ActiveContext = ActionExecutor.GetActiveContext(self.Entity)
	if not ActiveContext then
		return false
	end

	if ActiveContext.Metadata.ActionName ~= "Block" then
		return false
	end

	return ActionExecutor.Interrupt(self.Entity, "Released")
end

function NpcCombatComponent:Dodge(): (boolean, string?)
	if not self:CanAct() then
		return false, "CannotAct"
	end

	return ActionExecutor.Execute(self.Entity, "Dodge", "Dash", {})
end

function NpcCombatComponent:Interrupt(Reason: string?): boolean
	return ActionExecutor.Interrupt(self.Entity, Reason or "NpcInterrupt")
end

function NpcCombatComponent:IsActing(): boolean
	return ActionExecutor.GetActiveContext(self.Entity) ~= nil
end

function NpcCombatComponent:GetCurrentAction(): string?
	local Context = ActionExecutor.GetActiveContext(self.Entity)
	if Context then
		return Context.Metadata.ActionName
	end
	return nil
end

function NpcCombatComponent:SetTarget(Target: Types.Entity?)
	self.Target = Target
end

function NpcCombatComponent:GetTarget(): Types.Entity?
	return self.Target
end

function NpcCombatComponent:GetDistanceToTarget(): number?
	if not self.Target then
		return nil
	end

	local NpcRoot = self.Entity.Character and self.Entity.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local TargetRoot = self.Target.Character and self.Target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not NpcRoot or not TargetRoot then
		return nil
	end

	return (NpcRoot.Position - TargetRoot.Position).Magnitude
end

function NpcCombatComponent:IsTargetInRange(Range: number?): boolean
	local Distance = self:GetDistanceToTarget()
	local CheckRange = Range or self.AttackRange
	return Distance ~= nil and Distance <= CheckRange
end

function NpcCombatComponent:IsTargetInAttackRange(): boolean
	return self:IsTargetInRange(self.AttackRange)
end

function NpcCombatComponent:IsTargetInAggroRange(): boolean
	return self:IsTargetInRange(self.AggroRange)
end

function NpcCombatComponent:SetToolId(ToolId: number)
	self.ToolId = ToolId
end

function NpcCombatComponent:StopAutoAttack()
	self.IsRunning = false
end

function NpcCombatComponent:Destroy()
	self.IsRunning = false
	self.Target = nil
	self.Maid:DoCleaning()
end

return NpcCombatComponent