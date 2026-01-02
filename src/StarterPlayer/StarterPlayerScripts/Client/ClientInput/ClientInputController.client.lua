--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local InputBuffer = require(Shared.General.InputBuffer)
local Packets = require(Shared.Networking.Packets)
local ActionValidator = require(Shared.Utils.ActionValidator)
local ItemDatabase = require(Shared.Configurations.Data.ItemDatabase)
local AnimationSets = require(Shared.Configurations.Data.AnimationSets)
local DashBalance = require(Shared.Configurations.Balance.DashBalance)
local ClientDodgeHandler = require(script.Parent.ClientDodgeHandler)

local Player = Players.LocalPlayer

type PendingAction = {
        ActionName: string,
        Timestamp: number,
        StaminaCost: number?,
        IsPredicted: boolean?,
}

local PendingAction: PendingAction? = nil

local LocalState = {
	IsAttacking = false,
	IsBlocking = false,
	IsDodging = false,
	PredictedStamina = 0,
	LastStaminaSync = 0,
}

type LocalCooldownState = {
	DodgeEndTime: number,
}

local LocalCooldown: LocalCooldownState = {
        DodgeEndTime = 0,
}

local PENDING_ACTION_TIMEOUT = 1.0
local STAMINA_SYNC_INTERVAL = 0.5
local STEERABLE_DODGE = true
local AFRODASH_WINDOW = 0.2

local AFRODASH_ACTIONS: { [string]: boolean } = {
        M1 = true,
        M2 = true,
        Skill1 = true,
        Skill2 = true,
        Skill3 = true,
        Skill4 = true,
        Skill5 = true,
        Skill6 = true,
}

local AfrodashTimers: { [string]: number } = {}

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

local function GetLocalDodgeCooldownEndTime(Character: Model): number
	local AttributeEndTime = GetCooldownEndTimeFromAttribute(Character)
	if AttributeEndTime then
		return math.max(LocalCooldown.DodgeEndTime, AttributeEndTime)
	end

	return LocalCooldown.DodgeEndTime
end

local function IsDodgeOnCooldown(Character: Model): boolean
	local CurrentTime = os.clock()
	return CurrentTime < GetLocalDodgeCooldownEndTime(Character)
end

local function StartLocalDodgeCooldown(Character: Model)
	local CurrentTime = os.clock()

	local CooldownSecondsAttribute = Character:GetAttribute("DodgeCooldownSeconds") :: number?
	local CooldownSeconds = CooldownSecondsAttribute or (DashBalance.CooldownSeconds :: number?) or 0

	if CooldownSeconds > 0 then
		LocalCooldown.DodgeEndTime = math.max(LocalCooldown.DodgeEndTime, CurrentTime + CooldownSeconds)
	end
end

local function GetCharacter(): Model?
	return Player.Character
end

local function GetEquippedItemId(Character: Model): string?
	return Character:GetAttribute("EquippedItemId") :: string?
end

local function GetComboCount(Character: Model): number
	local ComboCount = Character:GetAttribute("M1ComboCount") :: number?
	return ComboCount or 1
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

local function GetComboLength(Character: Model): number?
        local AnimationSetName = GetAnimationSetName(Character)
        if not AnimationSetName then
                return nil
        end

        return AnimationSets.GetComboLength(AnimationSetName, "M1")
end

local function IsLastM1(Character: Model): boolean
        local ComboLength = GetComboLength(Character)
        if not ComboLength then
                return false
        end

        local ComboCount = GetComboCount(Character)
        return ComboCount >= ComboLength
end

local function IsAfrodashEligible(ActionName: string, Character: Model): boolean
        if ActionName == "M1" then
                return IsLastM1(Character)
        end

        if ActionName == "Dodge" then
                return true
        end

        return AFRODASH_ACTIONS[ActionName] == true
end

local function GetStaminaCostMultiplier(Character: Model): number
        local ItemId = GetEquippedItemId(Character)
        if not ItemId then
                return 1
        end

	local Item = ItemDatabase.GetItem(ItemId)
	if not Item then return 1 end
	local StatModifiers = Item["StatModifiers"]
	if StatModifiers and StatModifiers.StaminaCostMultiplier then
		return StatModifiers.StaminaCostMultiplier
	end

	return 1
end

local function SyncLocalState()
	local Character = GetCharacter()
	if not Character then
		return
	end

	LocalState.IsAttacking = Character:GetAttribute("Attacking") :: boolean? or false
	LocalState.IsBlocking = Character:GetAttribute("Blocking") :: boolean? or false

	local ServerStamina = Character:GetAttribute("Stamina") :: number? or 0
	local TimeSinceSync = os.clock() - LocalState.LastStaminaSync

	if TimeSinceSync > STAMINA_SYNC_INTERVAL or LocalState.PredictedStamina > ServerStamina then
		LocalState.PredictedStamina = ServerStamina
		LocalState.LastStaminaSync = os.clock()
	end
end

local function GetLocalStamina(): number
	local Character = GetCharacter()
	if not Character then
		return 0
	end

	local ServerStamina = Character:GetAttribute("Stamina") :: number? or 0
	return math.min(LocalState.PredictedStamina, ServerStamina)
end

local function DeductLocalStamina(Amount: number)
	LocalState.PredictedStamina = math.max(0, LocalState.PredictedStamina - Amount)
end

local function RefundLocalStamina(Amount: number)
	LocalState.PredictedStamina = LocalState.PredictedStamina + Amount
end

local function IsInputLocked(): boolean
        if not PendingAction then
                return false
        end

	local TimeSincePending = os.clock() - PendingAction.Timestamp
	if TimeSincePending > PENDING_ACTION_TIMEOUT then
		PendingAction = nil
		return false
	end

        return true
end

local function WasRecentAfrodashPartner(RawInput: string): boolean
        local Now = os.clock()

        if RawInput == "Dodge" then
                for ActionName, _ in AFRODASH_ACTIONS do
                        local LastTime = AfrodashTimers[ActionName]
                        if LastTime and (Now - LastTime) <= AFRODASH_WINDOW then
                                return true
                        end
                end
        elseif AFRODASH_ACTIONS[RawInput] then
                local LastDodge = AfrodashTimers["Dodge"]
                if LastDodge and (Now - LastDodge) <= AFRODASH_WINDOW then
                        return true
                end
        end

        return false
end

local function RecordAfrodashInput(RawInput: string)
        AfrodashTimers[RawInput] = os.clock()
end

local function ResolveActionName(RawInput: string): string
	if RawInput == "M1" then
		if LocalState.IsBlocking then
			return "PerfectGuard"
		end
		return "M1"
	end

	if RawInput == "M2" then
		if LocalState.IsBlocking then
			return "Counter"
		end
		if LocalState.IsAttacking then
			return "Feint"
		end
		return "M2"
	end

	return RawInput
end

local function GetM1StaminaCost(Character: Model): number?
	local AnimationSetName = GetAnimationSetName(Character)
	if not AnimationSetName then
		return nil
	end

	local ComboCount = GetComboCount(Character)
	local AttackData = AnimationSets.GetAttack(AnimationSetName, "M1", ComboCount)
	if not AttackData then
		return nil
	end

	local BaseCost = AttackData.StaminaCost
	local Multiplier = GetStaminaCostMultiplier(Character)

	return BaseCost * Multiplier
end

local function GetM2StaminaCost(Character: Model): number?
	local AnimationSetName = GetAnimationSetName(Character)
	if not AnimationSetName then
		return nil
	end

	local HeavyAttackData = AnimationSets.GetAttack(AnimationSetName, "M2", 1)
	if not HeavyAttackData then
		return nil
	end

	local BaseCost = HeavyAttackData.StaminaCost
	local Multiplier = GetStaminaCostMultiplier(Character)

	return BaseCost * Multiplier
end

local function GetStaminaCost(Character: Model, ResolvedAction: string): number?
	if ResolvedAction == "M1" or ResolvedAction == "LightAttack" then
		return GetM1StaminaCost(Character)
	end

	if ResolvedAction == "M2" or ResolvedAction == "HeavyAttack" then
		return GetM2StaminaCost(Character)
	end

	if ResolvedAction == "Dodge" then
		return 15
	end

	if ResolvedAction == "Feint" then
		return 0
	end

	if ResolvedAction == "PerfectGuard" or ResolvedAction == "Counter" or ResolvedAction == "Block" then
		return 0
	end

	return nil
end

local function CanPerformAction(RawInput: string, IsAfrodash: boolean?): (boolean, number?)
        local Character = GetCharacter()
        if not Character then
                return false, nil
        end

        local ResolvedAction = ResolveActionName(RawInput)

        local CanPerform, Reason = ActionValidator.CanPerformClient(Character, ResolvedAction)
        if not CanPerform then
                if IsAfrodash then
                        if ResolvedAction == "Dodge" and Reason == "Attacking" then
                                CanPerform = true
                        elseif (ResolvedAction == "M1" or ResolvedAction == "LightAttack" or ResolvedAction == "M2" or ResolvedAction == "HeavyAttack") and Reason == "Dodging" then
                                CanPerform = true
                        end
                end

                return false, nil
        end

        if ResolvedAction == "Dodge" then
                if IsDodgeOnCooldown(Character) then
			return false, nil
		end
	end

	local StaminaCost = GetStaminaCost(Character, ResolvedAction)
	if StaminaCost and StaminaCost > 0 and GetLocalStamina() < StaminaCost then
		return false, nil
	end

        return true, StaminaCost
end

local function TryExecuteAction(RawInput: string, InputData: { [string]: any }?, BypassLock: boolean?)
    SyncLocalState()

    if not BypassLock and IsInputLocked() then
        InputBuffer.BufferAction(RawInput)
        return
    end

    local CanPerform, StaminaCost = CanPerformAction(RawInput)
    if not CanPerform then
        InputBuffer.BufferAction(RawInput)
        return
    end

    local ResolvedAction = ResolveActionName(RawInput)

        if StaminaCost and StaminaCost > 0 then
                DeductLocalStamina(StaminaCost)
        end

        local IsPredicted = false

        if ResolvedAction == "Dodge" then
                local Started = ClientDodgeHandler.StartDodge(STEERABLE_DODGE)
                if Started then
                        LocalState.IsDodging = true
                        IsPredicted = true
                end
        elseif ResolvedAction == "M1" or ResolvedAction == "M2" then
                LocalState.IsAttacking = true
        end

        PendingAction = {
                ActionName = RawInput,
                Timestamp = os.clock(),
                StaminaCost = StaminaCost,
                IsPredicted = IsPredicted,
        }

        Packets.PerformAction:Fire(RawInput, InputData)
end

local function TryExecuteBufferedAction()
	local BufferedActions = { "M1", "M2", "Block", "Dodge" }

	for _, ActionName in BufferedActions do
		if InputBuffer.TryExecuteBuffered(ActionName) then
			return
		end
	end
end

local function ClearPendingAction()
	PendingAction = nil
end

local function RollbackPrediction()
	if not PendingAction then
		return
	end

	if PendingAction.StaminaCost and PendingAction.StaminaCost > 0 then
		RefundLocalStamina(PendingAction.StaminaCost)
	end

	local ResolvedAction = ResolveActionName(PendingAction.ActionName)

	if PendingAction.IsPredicted then
		if ResolvedAction == "Dodge" then
			ClientDodgeHandler.Rollback()
			LocalState.IsDodging = false
		end
	end

	if ResolvedAction == "M1" or ResolvedAction == "M2" then
		LocalState.IsAttacking = false
	end

	PendingAction = nil
end

InputBuffer.OnAction(function(ActionName: string)
        local Character = GetCharacter()
        if not Character then
                return
        end

        SyncLocalState()

        local IsAfrodash = WasRecentAfrodashPartner(ActionName)
        local InputData = if IsAfrodash then { Afrodash = true } else nil
        local ShouldBypassLock = IsAfrodash

        TryExecuteAction(ActionName, InputData, ShouldBypassLock)
        RecordAfrodashInput(ActionName)
end)

InputBuffer.OnRelease(function(ActionName: string)
	Packets.ReleaseAction:Fire(ActionName)
end)

Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
	if PendingAction and PendingAction.ActionName == ActionName then
		ClearPendingAction()
	end

	if ActionName == "Dodge" then
		local Character = GetCharacter()
		if Character then
			StartLocalDodgeCooldown(Character)
		end
	end

	TryExecuteBufferedAction()
end)

Packets.ActionDenied.OnClientEvent:Connect(function(_Reason: string)
	RollbackPrediction()
	TryExecuteBufferedAction()
end)

Packets.ActionCompleted.OnClientEvent:Connect(function(_Character: Instance, ActionName: string)
	LocalState.IsAttacking = false

	if ActionName == "Dodge" and LocalState.IsDodging then
		ClientDodgeHandler.StopDodge()
		LocalState.IsDodging = false
	end

	TryExecuteBufferedAction()
end)

Packets.ActionInterrupted.OnClientEvent:Connect(function(_Character: Instance, Reason: string)
	LocalState.IsAttacking = false

	if LocalState.IsDodging then
		if Reason == "Feint" or Reason == "Hit" or Reason == "Stunned" or Reason == "DodgeCancel" then
			ClientDodgeHandler.Rollback()
		else
			ClientDodgeHandler.StopDodge()
		end
		LocalState.IsDodging = false
	end

	TryExecuteBufferedAction()
end)

local function OnCharacterAdded(Character: Model)
	LocalState.IsAttacking = false
	LocalState.IsBlocking = false
	LocalState.IsDodging = false
	LocalState.PredictedStamina = Character:GetAttribute("Stamina") :: number? or 0
	LocalState.LastStaminaSync = os.clock()
	PendingAction = nil
	InputBuffer.ClearAllBuffers()

	ClientDodgeHandler.Rollback()

	Character:GetAttributeChangedSignal("Stamina"):Connect(function()
		local ServerStamina = Character:GetAttribute("Stamina") :: number? or 0
		if ServerStamina > LocalState.PredictedStamina then
			LocalState.PredictedStamina = ServerStamina
			LocalState.LastStaminaSync = os.clock()
		end
	end)

	Character:GetAttributeChangedSignal("Attacking"):Connect(function()
		local ServerAttacking = Character:GetAttribute("Attacking") :: boolean? or false
		if not ServerAttacking then
			LocalState.IsAttacking = false
		end
	end)

	Character:GetAttributeChangedSignal("Blocking"):Connect(function()
		LocalState.IsBlocking = Character:GetAttribute("Blocking") :: boolean? or false
	end)

	Character:GetAttributeChangedSignal("Dodging"):Connect(function()
		local ServerDodging = Character:GetAttribute("Dodging") :: boolean? or false
		if not ServerDodging and LocalState.IsDodging then
			ClientDodgeHandler.Rollback()
			LocalState.IsDodging = false
		end
	end)
end

Player.CharacterAdded:Connect(OnCharacterAdded)

if Player.Character then
	OnCharacterAdded(Player.Character)
end

ClientDodgeHandler.Init()