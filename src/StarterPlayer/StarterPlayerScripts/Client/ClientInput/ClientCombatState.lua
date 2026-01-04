--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local DashBalance = require(Shared.Configurations.Balance.DashBalance)

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
}

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

local function GetCooldownEndTimeFromAttribute(Character: Model): number?
	local DodgeCooldownEndTime = Character:GetAttribute("DodgeCooldownEndTime") :: number?
	if DodgeCooldownEndTime then
		return DodgeCooldownEndTime
	end

	local DodgeCooldownEnd = Character:GetAttribute("DodgeCooldownEnd") :: number?
	if DodgeCooldownEnd then
		return DodgeCooldownEnd
	end

	local DodgeCooldownUntil = Character:GetAttribute("DodgeCooldownUntil") :: number?
	if DodgeCooldownUntil then
		return DodgeCooldownUntil
	end

	local DodgeCooldown = Character:GetAttribute("DodgeCooldown") :: number?
	if DodgeCooldown then
		local CurrentTime = os.clock()
		if DodgeCooldown > CurrentTime then
			return DodgeCooldown
		end
		if DodgeCooldown > 0 then
			return CurrentTime + DodgeCooldown
		end
	end

	return nil
end

function ClientCombatState.IsDodgeOnCooldown(): boolean
	local Character = ClientCombatState.GetCharacter()
	if not Character then
		return true
	end

	local CurrentTime = os.clock()
	local AttributeEndTime = GetCooldownEndTimeFromAttribute(Character)
	local EndTime = LocalCooldown.DodgeEndTime

	if AttributeEndTime then
		EndTime = math.max(EndTime, AttributeEndTime)
	end

	return CurrentTime < EndTime
end

function ClientCombatState.StartDodgeCooldown()
	local Character = ClientCombatState.GetCharacter()
	if not Character then
		return
	end

	local CurrentTime = os.clock()
	local CooldownSecondsAttribute = Character:GetAttribute("DodgeCooldownSeconds") :: number?
	local CooldownSeconds = CooldownSecondsAttribute or (DashBalance.CooldownSeconds :: number?) or 0

	if CooldownSeconds > 0 then
		LocalCooldown.DodgeEndTime = math.max(LocalCooldown.DodgeEndTime, CurrentTime + CooldownSeconds)
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
end

return ClientCombatState