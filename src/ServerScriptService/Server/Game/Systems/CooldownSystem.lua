--!strict

local CooldownModule = {}
CooldownModule.__index = CooldownModule

export type CooldownData = {
	StartTime: number,
	Duration: number,
}

export type CooldownController = typeof(setmetatable(
	{} :: {
		Cooldowns: { [string]: CooldownData },
	},
	CooldownModule
))

local function GetServerTime(): number
	return workspace:GetServerTimeNow()
end

function CooldownModule.new(): CooldownController
	local self = setmetatable({
		Cooldowns = {},
	}, CooldownModule)

	return self
end

function CooldownModule:Start(CooldownId: string, DurationSeconds: number)
	self.Cooldowns[CooldownId] = {
		StartTime = GetServerTime(),
		Duration = DurationSeconds,
	}
end

function CooldownModule:IsOnCooldown(CooldownId: string): boolean
	local Cooldown = self.Cooldowns[CooldownId]
	if not Cooldown then
		return false
	end

	if GetServerTime() - Cooldown.StartTime >= Cooldown.Duration then
		self.Cooldowns[CooldownId] = nil
		return false
	end

	return true
end

function CooldownModule:GetRemaining(CooldownId: string): number
	local Cooldown = self.Cooldowns[CooldownId] :: CooldownData
	if not Cooldown then
		return 0
	end

	local Remaining = Cooldown.Duration - (GetServerTime() - Cooldown.StartTime)
	if Remaining <= 0 then
		self.Cooldowns[CooldownId] = nil
		return 0
	end

	return Remaining
end

function CooldownModule:GetProgress(CooldownId: string): number
	local Cooldown = self.Cooldowns[CooldownId]
	if not Cooldown then
		return 1
	end

	local Elapsed = GetServerTime() - Cooldown.StartTime
	local Progress = math.clamp(Elapsed / Cooldown.Duration, 0, 1)

	if Progress >= 1 then
		self.Cooldowns[CooldownId] = nil
	end

	return Progress
end

function CooldownModule:GetSnapshot(): { [string]: CooldownData }
	local Snapshot: { [string]: CooldownData } = {}
	local CurrentTime = GetServerTime()

	for CooldownId, Cooldown in self.Cooldowns do
		if CurrentTime - Cooldown.StartTime < Cooldown.Duration then
			Snapshot[CooldownId] = Cooldown
		else
			self.Cooldowns[CooldownId] = nil
		end
	end

	return Snapshot
end

function CooldownModule:Clear(CooldownId: string)
	self.Cooldowns[CooldownId] = nil
end

function CooldownModule:ClearAll()
	self.Cooldowns = {}
end

function CooldownModule:Destroy()
	self:ClearAll()
end

return CooldownModule
