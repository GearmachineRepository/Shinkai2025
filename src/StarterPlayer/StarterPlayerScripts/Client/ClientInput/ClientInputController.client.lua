--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local InputBuffer = require(Shared.Input.InputBuffer)
local Packets = require(Shared.Networking.Packets)
local ActionValidator = require(Shared.Utility.ActionValidator)
local InputResolverShared = require(Shared.Input.InputResolverShared)
local ClientDodgeHandler = require(script.Parent.ClientDodgeHandler)
local ClientCombatState = require(script.Parent.ClientCombatState)
local ClientSprintHandler = require(script.Parent.ClientSprintHandler)

local Player = Players.LocalPlayer

type PendingAction = {
	ActionName: string,
	Timestamp: number,
	StaminaCost: number?,
	IsPredicted: boolean?,
}

local PendingAction: PendingAction? = nil

local PENDING_ACTION_TIMEOUT = 1.0
local STEERABLE_DODGE = true

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

local function ResolveActionName(RawInput: string): string
	local States = ClientCombatState.BuildStateTable()
	return InputResolverShared.ResolveFromTable(RawInput, States) or RawInput
end

local function CanPerformAction(RawInput: string): (boolean, number?)
	local Character = ClientCombatState.GetCharacter()
	if not Character then
		return false, nil
	end

	local ResolvedAction = ResolveActionName(RawInput)
	if not ResolvedAction then
		return false, nil
	end

	local CanPerform, _Reason = ActionValidator.CanPerformClient(Character, ResolvedAction)
	if not CanPerform then
		return false, nil
	end

	if ResolvedAction == "Dodge" and ClientCombatState.IsDodgeOnCooldown() then
		return false, nil
	end

	local StaminaCost = ClientCombatState.GetStaminaCost(ResolvedAction)
	if StaminaCost and StaminaCost > 0 and ClientCombatState.GetStamina() < StaminaCost then
		return false, nil
	end

	return true, StaminaCost
end

local function TryExecuteAction(RawInput: string)
	ClientCombatState.SyncFromServer()

	local CanPerform, StaminaCost = CanPerformAction(RawInput)
	if not CanPerform then
		InputBuffer.BufferAction(RawInput)
		return
	end

	local ResolvedAction = ResolveActionName(RawInput)

	if StaminaCost and StaminaCost > 0 then
		ClientCombatState.DeductStamina(StaminaCost)
	end

	local IsPredicted = false

	if ResolvedAction == "Dodge" then
		local Started = ClientDodgeHandler.StartDodge(STEERABLE_DODGE)
		if not Started then
			return
		end
		ClientCombatState.SetState("Dodging", true)
		IsPredicted = true
	elseif ResolvedAction == "M1" or ResolvedAction == "M2" then
		ClientCombatState.SetState("Attacking", true)
	end

	PendingAction = {
		ActionName = RawInput,
		Timestamp = os.clock(),
		StaminaCost = StaminaCost,
		IsPredicted = IsPredicted,
	}

	local InputTimestamp = workspace:GetServerTimeNow()
	local InputData: { [string]: any }? = nil

	if ResolvedAction == "Dodge" then
		local Direction = ClientDodgeHandler.GetLastDirection()
		InputData = { Direction = Direction }
	end

	Packets.PerformAction:Fire(RawInput, InputTimestamp, InputData)
end

local function TryExecuteBufferedAction()
	local BufferedActions = { "M1", "M2", "Block", "Dodge" }

	for _, ActionName in BufferedActions do
		if ActionName == "Block" and not InputBuffer.IsHeld("Block") then
			InputBuffer.ClearBuffer("Block")
			continue
		end

		if InputBuffer.TryExecuteBuffered(ActionName) then
			return
		end
	end
end

local function TryExecuteBufferedSprint()
	if not ClientSprintHandler.IsSprintIntentActive() then
		return
	end

	if not InputBuffer.IsHeld("Sprint") then
		return
	end

	if not ClientSprintHandler.CanStartSprint() then
		return
	end

	ClientSprintHandler.StartSprint()
end

local function RollbackPrediction()
	if not PendingAction then
		return
	end

	if PendingAction.StaminaCost and PendingAction.StaminaCost > 0 then
		ClientCombatState.RefundStamina(PendingAction.StaminaCost)
	end

	local ResolvedAction = ResolveActionName(PendingAction.ActionName)

	if PendingAction.IsPredicted and ResolvedAction == "Dodge" then
		ClientDodgeHandler.Rollback()
		ClientCombatState.SetState("Dodging", false)
	end

	if ResolvedAction == "M1" or ResolvedAction == "M2" then
		ClientCombatState.SetState("Attacking", false)
	end

	PendingAction = nil
end

InputBuffer.OnAction(function(ActionName: string)
	if ActionName == "Sprint" then
		local IsDoubleTap = ClientSprintHandler.OnWPress()
		if IsDoubleTap then
			if ClientSprintHandler.CanStartSprint() then
				ClientSprintHandler.StartSprint()
			end
		end
		return
	end

	if not ClientCombatState.GetCharacter() then
		return
	end

	ClientCombatState.SyncFromServer()

	if IsInputLocked() then
		InputBuffer.BufferAction(ActionName)
		return
	end

	TryExecuteAction(ActionName)
end)

InputBuffer.OnRelease(function(ActionName: string)
	if ActionName == "Sprint" then
		ClientSprintHandler.OnWRelease()
		return
	end

	Packets.ReleaseAction:Fire(ActionName)
end)

Packets.ActionApproved.OnClientEvent:Connect(function(ActionName: string)
	if PendingAction and PendingAction.ActionName == ActionName then
		PendingAction = nil
	end

	if ActionName == "Dodge" then
		local Direction = ClientDodgeHandler.GetLastDirection()
		ClientCombatState.StartDodgeCooldown(Direction)
	end

	TryExecuteBufferedAction()
end)

Packets.ActionDenied.OnClientEvent:Connect(function(_Reason: string)
	RollbackPrediction()
	TryExecuteBufferedAction()
end)

Packets.ActionCompleted.OnClientEvent:Connect(function(_Character: Instance, ActionName: string)
	ClientCombatState.SetState("Attacking", false)

	if ActionName == "Dodge" and ClientCombatState.GetState("Dodging") then
		ClientDodgeHandler.StopDodge()
		ClientCombatState.SetState("Dodging", false)
	end

	TryExecuteBufferedAction()
end)

Packets.ActionInterrupted.OnClientEvent:Connect(function(_Character: Instance, ActionName: string, Reason: string)
	if ActionName == "LightAttack" or ActionName == "HeavyAttack" then
		ClientCombatState.SetState("Attacking", false)
	end

	if ActionName == "Dodge" and ClientCombatState.GetState("Dodging") then
		if Reason == "Feint" or Reason == "Hit" or Reason == "Stunned" or Reason == "DodgeCancel" then
			ClientDodgeHandler.Rollback()
		else
			ClientDodgeHandler.StopDodge()
		end
		ClientCombatState.SetState("Dodging", false)
	end

	if ActionName == "Block" then
		ClientCombatState.SetState("Blocking", false)
	end

	TryExecuteBufferedAction()
end)

local function OnCharacterAdded(Character: Model)
	ClientCombatState.Reset()
	ClientSprintHandler.Reset()
	PendingAction = nil
	InputBuffer.ClearAllBuffers()
	ClientDodgeHandler.Rollback()

	Character:GetAttributeChangedSignal("Stamina"):Connect(function()
		local ServerStamina = Character:GetAttribute("Stamina") :: number? or 0
		ClientCombatState.SyncStaminaFromServer(ServerStamina)
	end)

	Character:GetAttributeChangedSignal("Attacking"):Connect(function()
		if not Character:GetAttribute("Attacking") then
			ClientCombatState.SetState("Attacking", false)
		end
	end)

	Character:GetAttributeChangedSignal("Blocking"):Connect(function()
		ClientCombatState.SetState("Blocking", Character:GetAttribute("Blocking") == true)
	end)

	Character:GetAttributeChangedSignal("Dodging"):Connect(function()
		if not Character:GetAttribute("Dodging") and ClientCombatState.GetState("Dodging") then
			ClientDodgeHandler.Rollback()
			ClientCombatState.SetState("Dodging", false)
		end
	end)

	Character:GetAttributeChangedSignal("MovementMode"):Connect(function()
		local ServerMode = Character:GetAttribute("MovementMode") :: string?
		if ServerMode then
			ClientSprintHandler.SyncFromServer(ServerMode)
		end
	end)

	Character:GetAttributeChangedSignal("Stunned"):Connect(function()
		local IsStunned = Character:GetAttribute("Stunned") == true
		ClientCombatState.SetState("Stunned", IsStunned)

		if IsStunned then
			if ClientCombatState.GetState("Dodging") then
				ClientDodgeHandler.Rollback()
				ClientCombatState.SetState("Dodging", false)
			end
			InputBuffer.ClearAllBuffers()
			return
		end

		if InputBuffer.IsHeld("Block") then
			task.defer(function()
				TryExecuteAction("Block")
			end)
		end

		task.defer(TryExecuteBufferedSprint)
	end)

	Character:GetAttributeChangedSignal("Exhausted"):Connect(function()
		local IsExhausted = Character:GetAttribute("Exhausted") == true
		if IsExhausted then
			return
		end

		task.defer(TryExecuteBufferedSprint)
	end)
end

Player.CharacterAdded:Connect(OnCharacterAdded)

if Player.Character then
	OnCharacterAdded(Player.Character)
end

ClientDodgeHandler.Init()