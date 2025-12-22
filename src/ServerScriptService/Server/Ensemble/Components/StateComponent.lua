--!strict

local Signal = require(script.Parent.Parent.Utilities.Signal)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local EventBus = require(script.Parent.Parent.Utilities.EventBus)
local StateSchema = require(script.Parent.Parent.Schemas.StateSchema)
local Types = require(script.Parent.Parent.Types)

type StateConfig = Types.StateConfig
type Connection = Types.Connection

type StateComponentInternal = Types.StateComponent & {
	Entity: Types.Entity,
	Config: StateConfig,
	CurrentStates: { [string]: boolean },
	StateSignals: { [string]: Types.Signal<boolean> },
	Maid: Types.Maid,
}

local StateComponent = {}
StateComponent.__index = StateComponent

local ActiveConfig: StateConfig? = nil

function StateComponent.SetConfig(Config: StateConfig)
	ActiveConfig = Config
end

function StateComponent.new(Entity: Types.Entity): Types.StateComponent
	if not ActiveConfig then
		error(Types.EngineName .. " StateComponent.SetConfig must be called before creating entities")
	end

	local self: StateComponentInternal = setmetatable({
		Entity = Entity,
		Config = ActiveConfig,
		CurrentStates = {},
		StateSignals = {},
		Maid = Maid.new(),
	}, StateComponent) :: any

	for StateName in ActiveConfig.States do
		self.CurrentStates[StateName] = StateSchema.GetDefault(ActiveConfig, StateName)
		self.StateSignals[StateName] = Signal.new()
		self.Maid:GiveTask(self.StateSignals[StateName])
	end

	return self
end

function StateComponent:GetState(StateName: string): boolean
	return self.CurrentStates[StateName] or false
end

function StateComponent:SetState(StateName: string, Value: boolean)
	local Definition = self.Config.States[StateName]
	if not Definition then
		warn(string.format(Types.EngineName .. " Unknown state: '%s'", StateName))
		return
	end

	if self.CurrentStates[StateName] == Value then
		return
	end

	if Value then
		local Conflicts = StateSchema.GetConflicts(self.Config, StateName)
		for _, ConflictState in Conflicts do
			if self.CurrentStates[ConflictState] then
				self:SetState(ConflictState, false)
			end
		end
	end

	self.CurrentStates[StateName] = Value

	local Replication = StateSchema.GetReplication(self.Config, StateName)
	if Replication ~= "None" and self.Entity.Character then
		self.Entity.Character:SetAttribute(StateName, Value)
	end

	local StateSignal = self.StateSignals[StateName]
	if StateSignal then
		StateSignal:Fire(Value)
	end

	EventBus.Publish("StateChanged", {
		Entity = self.Entity,
		Character = self.Entity.Character,
		StateName = StateName,
		Value = Value,
		Replication = Replication,
	})
end

function StateComponent:OnStateChanged(StateName: string, Callback: (Value: boolean) -> ()): Connection
	local StateSignal = self.StateSignals[StateName]
	if not StateSignal then
		StateSignal = Signal.new()
		self.StateSignals[StateName] = StateSignal
		self.Maid:GiveTask(StateSignal)
	end

	return StateSignal:Connect(Callback)
end

function StateComponent:GetAllStates(): { [string]: boolean }
	return table.clone(self.CurrentStates)
end

function StateComponent:LocksMovement(): boolean
	for StateName, IsActive in self.CurrentStates do
		if IsActive and StateSchema.LocksMovement(self.Config, StateName) then
			return true
		end
	end
	return false
end

function StateComponent:Destroy()
	self.Maid:DoCleaning()
	table.clear(self.CurrentStates)
	table.clear(self.StateSignals)
end

return StateComponent