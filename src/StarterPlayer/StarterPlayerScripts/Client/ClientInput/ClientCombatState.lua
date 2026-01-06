--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ItemDatabase = require(Shared.Config.Data.ItemDatabase)
local AnimationSets = require(Shared.Config.Data.AnimationSets)
local PhysicsBalance = require(Shared.Config.Balance.PhysicsBalance)

local Player = Players.LocalPlayer

local STAMINA_SYNC_INTERVAL = 0.5

local ClientCombatState = {}

local LocalState = {
	IsAttacking = false,
	IsBlocking = false,
	IsDodging = false,
	IsStunned = false,
	IsGuardbroken = false,
	IsExhausted = false,
	IsDowned = false,
	IsRagdolled = false,
	PredictedStamina = 0,
	LastStaminaSync = 0,
}

local LocalCooldown = {
	DodgeEndTime = 0,
	DashCount = 0,
	LastDirection = nil :: string?,
	LastDashTime = 0,
}

local CONSECUTIVE_DASHES = PhysicsBalance.Dash.ConsecutiveDashes
local CONSECUTIVE_COOLDOWN = PhysicsBalance.Dash.ConsecutiveCooldown
local COOLDOWN_SECONDS = PhysicsBalance.Dash.CooldownSeconds
local COMBO_RESET_TIME = PhysicsBalance.Dash.ComboResetTime

local function CheckComboExpiry()
	if LocalCooldown.DashCount == 0 then
		return
	end

	local TimeSinceLastDash = os.clock() - LocalCooldown.LastDashTime
	if TimeSinceLastDash >= COMBO_RESET_TIME then
		LocalCooldown.DashCount = 0
		LocalCooldown.LastDirection = nil
	end
end

function ClientCombatState.GetDashCount(): number
	CheckComboExpiry()
	return LocalCooldown.DashCount
end

function ClientCombatState.CanDodgeDirection(Direction: string): boolean
	CheckComboExpiry()
	return LocalCooldown.LastDirection ~= Direction
end

function ClientCombatState.GetCharacter(): Model?
	return Player.Character
end

function ClientCombatState.GetState(StateName: string): boolean
	if StateName == "Attacking" then return LocalState.IsAttacking end
	if StateName == "Blocking" then return LocalState.IsBlocking end
	if StateName == "Dodging" then return LocalState.IsDodging end
	if StateName == "Stunned" then return LocalState.IsStunned end
	if StateName == "GuardBroken" then return LocalState.IsGuardbroken end
	if StateName == "Exhausted" then return LocalState.IsExhausted end
	if StateName == "Downed" then return LocalState.IsDowned end
	if StateName == "Ragdolled" then return LocalState.IsRagdolled end

	local Character = ClientCombatState.GetCharacter()
	if Character then
		return Character:GetAttribute(StateName) == true
	end

	return false
end

function ClientCombatState.SetState(StateName: string, Value: boolean)
	if StateName == "Attacking" then
        LocalState.IsAttacking = Value
    end
	if StateName == "Blocking" then
        LocalState.IsBlocking = Value
    end
	if StateName == "Dodging" then
        LocalState.IsDodging = Value
    end
	if StateName == "Stunned" then
        LocalState.IsStunned = Value
    end
	if StateName == "GuardBroken" then
        LocalState.IsGuardbroken = Value
    end
	if StateName == "Exhausted" then
        LocalState.IsExhausted = Value
    end
	if StateName == "Downed" then
        LocalState.IsDowned = Value
    end
	if StateName == "Ragdolled" then
        LocalState.IsRagdolled = Value
    end
end

function ClientCombatState.BuildStateTable(): { [string]: boolean }
	local Character = ClientCombatState.GetCharacter()
	local States: { [string]: boolean } = {
		Attacking = LocalState.IsAttacking,
		Blocking = LocalState.IsBlocking,
		Dodging = LocalState.IsDodging,
		Stunned = LocalState.IsStunned,
		GuardBroken = LocalState.IsGuardbroken,
		Exhausted = LocalState.IsExhausted,
		Downed = LocalState.IsDowned,
		Ragdolled = LocalState.IsRagdolled,
	}

	if Character then
		local Airborne = Character:GetAttribute("Airborne")
		if Airborne then
			States.Airborne = true
		end
	end

	return States
end

function ClientCombatState.SyncFromServer()
	local Character = ClientCombatState.GetCharacter()
	if not Character then
		return
	end

	LocalState.IsAttacking = Character:GetAttribute("Attacking") == true
	LocalState.IsBlocking = Character:GetAttribute("Blocking") == true

	local ServerStamina = Character:GetAttribute("Stamina") :: number? or 0
	local TimeSinceSync = os.clock() - LocalState.LastStaminaSync

	if TimeSinceSync > STAMINA_SYNC_INTERVAL or LocalState.PredictedStamina > ServerStamina then
		LocalState.PredictedStamina = ServerStamina
		LocalState.LastStaminaSync = os.clock()
	end
end

function ClientCombatState.GetStamina(): number
	local Character = ClientCombatState.GetCharacter()
	if not Character then
		return 0
	end

	local ServerStamina = Character:GetAttribute("Stamina") :: number? or 0
	return math.min(LocalState.PredictedStamina, ServerStamina)
end

function ClientCombatState.DeductStamina(Amount: number)
	LocalState.PredictedStamina = math.max(0, LocalState.PredictedStamina - Amount)
end

function ClientCombatState.RefundStamina(Amount: number)
	LocalState.PredictedStamina = LocalState.PredictedStamina + Amount
end

function ClientCombatState.SyncStaminaFromServer(ServerStamina: number)
	if ServerStamina > LocalState.PredictedStamina then
		LocalState.PredictedStamina = ServerStamina
		LocalState.LastStaminaSync = os.clock()
	end
end

local function GetEquippedItemId(Character: Model): string?
	return Character:GetAttribute("EquippedItemId") :: string?
end

local function GetAnimationSetName(Character: Model): string?
	local ItemId = GetEquippedItemId(Character)
	if not ItemId then
		return nil
	end

	local ItemData = ItemDatabase.GetItem(ItemId)
	if not ItemData then
		return nil
	end

	return ItemData.AnimationSet
end

local function GetStaminaCostMultiplier(Character: Model): number
	local ItemId = GetEquippedItemId(Character)
	if not ItemId then
		return 1
	end

	local Item = ItemDatabase.GetItem(ItemId)
	if not Item then
		return 1
	end

	local StatModifiers = Item["StatModifiers"]
	if StatModifiers and StatModifiers.StaminaCostMultiplier then
		return StatModifiers.StaminaCostMultiplier
	end

	return 1
end

local function GetComboCount(Character: Model): number
	return Character:GetAttribute("M1ComboCount") :: number? or 1
end

function ClientCombatState.GetStaminaCost(ResolvedAction: string): number?
	local Character = ClientCombatState.GetCharacter()
	if not Character then
		return nil
	end

	if ResolvedAction == "M1" or ResolvedAction == "LightAttack" then
		local AnimationSetName = GetAnimationSetName(Character)
		if not AnimationSetName then
			return nil
		end

		local ComboCount = GetComboCount(Character)
		local AttackData = AnimationSets.GetAttack(AnimationSetName, "M1", ComboCount)
		if not AttackData then
			return nil
		end

		return AttackData.StaminaCost * GetStaminaCostMultiplier(Character)
	end

	if ResolvedAction == "M2" or ResolvedAction == "HeavyAttack" then
		local AnimationSetName = GetAnimationSetName(Character)
		if not AnimationSetName then
			return nil
		end

		local AttackData = AnimationSets.GetAttack(AnimationSetName, "M2", 1)
		if not AttackData then
			return nil
		end

		return AttackData.StaminaCost * GetStaminaCostMultiplier(Character)
	end

	if ResolvedAction == "Dodge" then
		return 15
	end

	return 0
end

function ClientCombatState.IsDodgeOnCooldown(): boolean
	local CurrentTime = os.clock()

	if CurrentTime < LocalCooldown.DodgeEndTime then
		return true
	end

	CheckComboExpiry()

	if LocalCooldown.DashCount >= CONSECUTIVE_DASHES then
		return true
	end

	return false
end

function ClientCombatState.ResetDashCombo()
	LocalCooldown.DashCount = 0
	LocalCooldown.LastDirection = nil
end

function ClientCombatState.StartDodgeCooldown(Direction: string?)
	local CurrentTime = os.clock()

	CheckComboExpiry()

	LocalCooldown.DashCount = LocalCooldown.DashCount + 1
	LocalCooldown.LastDashTime = CurrentTime
	LocalCooldown.LastDirection = Direction

	local IsLastDash = LocalCooldown.DashCount >= CONSECUTIVE_DASHES

	if IsLastDash then
		LocalCooldown.DodgeEndTime = CurrentTime + COOLDOWN_SECONDS
		LocalCooldown.DashCount = 0
		LocalCooldown.LastDirection = nil
	else
		LocalCooldown.DodgeEndTime = CurrentTime + CONSECUTIVE_COOLDOWN
	end
end

function ClientCombatState.Reset()
	LocalState.IsAttacking = false
	LocalState.IsBlocking = false
	LocalState.IsDodging = false
	LocalState.IsStunned = false
	LocalState.IsGuardbroken = false
	LocalState.IsExhausted = false
	LocalState.IsDowned = false
	LocalState.IsRagdolled = false

	local Character = ClientCombatState.GetCharacter()
	if Character then
		LocalState.PredictedStamina = Character:GetAttribute("Stamina") :: number? or 0
	else
		LocalState.PredictedStamina = 0
	end

	LocalState.LastStaminaSync = os.clock()

	LocalCooldown.DodgeEndTime = 0
	LocalCooldown.DashCount = 0
	LocalCooldown.LastDirection = nil
	LocalCooldown.LastDashTime = 0
end

return ClientCombatState