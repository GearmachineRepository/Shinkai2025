--!strict

local Signal = require(script.Parent.Parent.Utilities.Signal)
local Maid = require(script.Parent.Parent.Utilities.Maid)
local EventBus = require(script.Parent.Parent.Utilities.EventBus)
local StatSchema = require(script.Parent.Parent.Schemas.StatSchema)
local Types = require(script.Parent.Parent.Types)

type StatConfig = Types.StatConfig
type Connection = Types.Connection

type StatComponentInternal = Types.StatComponent & {
	Entity: any,
	Config: StatConfig,
	CurrentStats: { [string]: number },
	StatSignals: { [string]: Types.Signal<number, number> },
	Maid: Types.Maid,
}

local StatComponent = {}
StatComponent.__index = StatComponent

local ActiveConfig: StatConfig? = nil

local UPDATE_THRESHOLD = 0.001

function StatComponent.SetConfig(Config: StatConfig)
	ActiveConfig = Config
end

function StatComponent.new(Entity: any, InitialData: { [string]: any }?): Types.StatComponent
	if not ActiveConfig then
		error(" StatComponent.SetConfig must be called before creating entities")
	end

	local self: StatComponentInternal = setmetatable({
		Entity = Entity,
		Config = ActiveConfig,
		CurrentStats = {},
		StatSignals = {},
		Maid = Maid.new(),
	}, StatComponent) :: any

	for StatName in ActiveConfig.Stats do
		local DefaultValue = StatSchema.GetDefault(ActiveConfig, StatName)
		local InitialValue = InitialData and InitialData[StatName] or DefaultValue
		self.CurrentStats[StatName] = InitialValue
		self.StatSignals[StatName] = Signal.new()
		self.Maid:GiveTask(self.StatSignals[StatName])
	end

	for StatName, Value in self.CurrentStats do
		local Replication = StatSchema.GetReplication(self.Config, StatName)
		if Replication ~= "None" then
			self.Entity.Character:SetAttribute(StatName, Value)
		end
	end

	return self
end

function StatComponent:GetStat(StatName: string): number
	return self.CurrentStats[StatName] or 0
end

function StatComponent:SetStat(StatName: string, Value: number)
	local Definition = self.Config.Stats[StatName]
	if not Definition then
		warn(string.format(" Unknown stat: '%s'", StatName))
		return
	end

	local ClampedValue = StatSchema.ClampValue(self.Config, StatName, Value)
	local OldValue = self.CurrentStats[StatName] or 0

	if math.abs(ClampedValue - OldValue) < UPDATE_THRESHOLD then
		return
	end

	self.CurrentStats[StatName] = ClampedValue

	local Replication = StatSchema.GetReplication(self.Config, StatName)
	if Replication ~= "None" and self.Entity.Character then
		self.Entity.Character:SetAttribute(StatName, ClampedValue)
	end

	local StatSignal = self.StatSignals[StatName]
	if StatSignal then
		StatSignal:Fire(ClampedValue, OldValue)
	end

	EventBus.Publish("StatChanged", {
		Entity = self.Entity,
		Character = self.Entity.Character,
		StatName = StatName,
		NewValue = ClampedValue,
		OldValue = OldValue,
		Replication = Replication,
	})
end

function StatComponent:ModifyStat(StatName: string, Delta: number)
	local CurrentValue = self:GetStat(StatName) or 0
	self:SetStat(StatName, CurrentValue + Delta)
end

function StatComponent:GetAllStats(): { [string]: number }
	return table.clone(self.CurrentStats)
end

function StatComponent:OnStatChanged(StatName: string, Callback: (NewValue: number, OldValue: number) -> ()): Connection
	local StatSignal = self.StatSignals[StatName]
	if not StatSignal then
		StatSignal = Signal.new()
		self.StatSignals[StatName] = StatSignal
		self.Maid:GiveTask(StatSignal)
	end

	return StatSignal:Connect(Callback)
end

function StatComponent:ReplicateAll()
	if not self.Entity.Character then
		return
	end

	for StatName, Value in self.CurrentStats do
		local Replication = StatSchema.GetReplication(self.Config, StatName)
		if Replication ~= "None" then
			self.Entity.Character:SetAttribute(StatName, Value)
		end
	end
end

function StatComponent:Destroy()
	self.Maid:DoCleaning()
	table.clear(self.CurrentStats)
	table.clear(self.StatSignals)
end

return StatComponent