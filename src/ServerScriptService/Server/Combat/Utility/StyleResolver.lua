--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local ItemDatabase = require(Shared.Config.Data.ItemDatabase)
local StyleConfig = require(Shared.Config.Styles.StyleConfig)

type Entity = CombatTypes.Entity

local StyleResolver = {}

local DEFAULT_STYLE = "Fists"

function StyleResolver.GetEquippedItemId(Entity: Entity, InputData: { [string]: any }?): string?
	if InputData and InputData.ItemId then
		return InputData.ItemId
	end

	local ToolComponent = Entity:GetComponent("Tool")
	if not ToolComponent then
		return nil
	end

	local EquippedTool = ToolComponent:GetEquippedTool()
	if not EquippedTool or not EquippedTool.ToolId then
		return nil
	end

	return EquippedTool.ToolId
end

function StyleResolver.GetStyleFromItemId(ItemId: string?): string?
	if not ItemId then
		return nil
	end

	local ItemData = ItemDatabase.GetItem(ItemId)
	if not ItemData then
		return nil
	end

	return ItemData.Style
end

function StyleResolver.GetEntityStyle(Entity: Entity, InputData: { [string]: any }?): string?
	local ItemId = StyleResolver.GetEquippedItemId(Entity, InputData)
	if not ItemId then
		return nil
	end

	return StyleResolver.GetStyleFromItemId(ItemId)
end

function StyleResolver.GetEntityStyleOrDefault(Entity: Entity, InputData: { [string]: any }?): string
	local Style = StyleResolver.GetEntityStyle(Entity, InputData)
	return Style or DEFAULT_STYLE
end

function StyleResolver.GetItemData(Entity: Entity, InputData: { [string]: any }?): ItemDatabase.ItemDefinition?
	local ItemId = StyleResolver.GetEquippedItemId(Entity, InputData)
	if not ItemId then
		return nil
	end

	return ItemDatabase.GetItem(ItemId)
end

function StyleResolver.GetModifiers(Entity: Entity, InputData: { [string]: any }?): ItemDatabase.Modifiers?
	local ItemData = StyleResolver.GetItemData(Entity, InputData)
	if not ItemData then
		return nil
	end

	return ItemData.Modifiers
end

function StyleResolver.GetAttackData(Entity: Entity, ComboKey: string, ComboIndex: number, InputData: { [string]: any }?): StyleConfig.AttackData?
	local StyleName = StyleResolver.GetEntityStyle(Entity, InputData)
	if not StyleName then
		return nil
	end

	return StyleConfig.GetAttack(StyleName, ComboKey, ComboIndex)
end

function StyleResolver.GetTiming(Entity: Entity, InputData: { [string]: any }?): StyleConfig.TimingConfig
	local StyleName = StyleResolver.GetEntityStyle(Entity, InputData)
	if StyleName then
		return StyleConfig.GetTiming(StyleName)
	end

	return StyleConfig.GetTiming(DEFAULT_STYLE)
end

function StyleResolver.GetComboLength(Entity: Entity, ComboKey: string, InputData: { [string]: any }?): number
	local StyleName = StyleResolver.GetEntityStyle(Entity, InputData)
	if not StyleName then
		return 1
	end

	return StyleConfig.GetComboLength(StyleName, ComboKey)
end

function StyleResolver.ApplyModifier(BaseValue: number, Multiplier: number?): number
	if Multiplier then
		return BaseValue * Multiplier
	end
	return BaseValue
end

return StyleResolver