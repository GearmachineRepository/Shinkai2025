--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VfxModules = Shared:WaitForChild("VFX"):WaitForChild("Modules")

export type VfxInstance = {
	Cleanup: (Rollback: boolean?) -> (),
	Stop: (() -> ())?,
}

export type ActiveVfxMap = { [Model]: { [string]: VfxInstance } }

local VfxPlayer = {}

local ActiveVfxByCharacter: ActiveVfxMap = {}

local function GetVfxModule(VfxName: string): any?
	local VfxModule = VfxModules:FindFirstChild(VfxName)
	if not VfxModule or not VfxModule:IsA("ModuleScript") then
		warn("VFX module not found:", VfxName)
		return nil
	end

	local Success, Result = pcall(require, VfxModule)
	if not Success then
		warn("Failed to load VFX module:", VfxName, Result)
		return nil
	end

	return Result
end

function VfxPlayer.Play(Character: Model, VfxName: string, VfxData: unknown?): VfxInstance?
	local VfxModule = GetVfxModule(VfxName)
	if not VfxModule or VfxModule.Play == nil then
		return nil
	end

	VfxPlayer.Cleanup(Character, VfxName, false)

	local VfxInstanceValue: VfxInstance? = VfxModule.Play(Character, VfxData)
	if not VfxInstanceValue then
		return nil
	end

	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		CharacterVfx = {}
		ActiveVfxByCharacter[Character] = CharacterVfx
	end

	CharacterVfx[VfxName] = VfxInstanceValue
	return VfxInstanceValue
end

function VfxPlayer.Stop(Character: Model, VfxName: string)
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return
	end

	local VfxInstanceValue = CharacterVfx[VfxName]
	if not VfxInstanceValue then
		return
	end

	local StopFunction = VfxInstanceValue.Stop
	if StopFunction then
		StopFunction()
	end

	CharacterVfx[VfxName] = nil
end

function VfxPlayer.Cleanup(Character: Model, VfxName: string, Rollback: boolean?)
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return
	end

	local VfxInstanceValue = CharacterVfx[VfxName]
	if not VfxInstanceValue then
		return
	end

	VfxInstanceValue.Cleanup(Rollback)
	CharacterVfx[VfxName] = nil
end

function VfxPlayer.CleanupAll(Character: Model, Rollback: boolean?)
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return
	end

	for _, VfxInstanceValue in CharacterVfx do
		VfxInstanceValue.Cleanup(Rollback)
	end

	ActiveVfxByCharacter[Character] = nil
end

function VfxPlayer.HasActive(Character: Model, VfxName: string): boolean
	local CharacterVfx = ActiveVfxByCharacter[Character]
	if not CharacterVfx then
		return false
	end
	return CharacterVfx[VfxName] ~= nil
end

function VfxPlayer.GetActiveMap(): ActiveVfxMap
	return ActiveVfxByCharacter
end

return VfxPlayer
