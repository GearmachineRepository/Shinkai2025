--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local CombatTypes = require(script.Parent.Parent.CombatTypes)
local ComboTracker = require(script.Parent.ComboTracker)
local StyleResolver = require(script.Parent.Parent.Utility.StyleResolver)

local StyleConfig = require(Shared.Config.Styles.StyleConfig)

type Entity = CombatTypes.Entity
type ActionMetadata = CombatTypes.ActionMetadata

local MetadataBuilders = {}

function MetadataBuilders.ComboAttack(ComboKey: string, ActionName: string)
	return function(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
		local StyleName = StyleResolver.GetEntityStyle(Entity, InputData)
		if not StyleName then
			return nil
		end

		local ComboIndex = ComboTracker.GetCount(Entity, ActionName)
		local AttackData = StyleConfig.GetAttack(StyleName, ComboKey, ComboIndex)
		local Timing = StyleConfig.GetTiming(StyleName)

		if not AttackData then
			return nil
		end

		local Modifiers = StyleResolver.GetModifiers(Entity, InputData)

		return {
			ActionName = ActionName,
			ActionType = "Attack",
			AnimationSet = StyleName,
			AnimationId = AttackData.AnimationId,
			ComboIndex = ComboIndex,

			Damage = StyleResolver.ApplyModifier(AttackData.Damage, Modifiers and Modifiers.DamageMultiplier),
			StaminaCost = StyleResolver.ApplyModifier(AttackData.StaminaCost, Modifiers and Modifiers.StaminaCostMultiplier),
			HitStun = AttackData.HitStun,

			HitboxSize = AttackData.Hitbox and AttackData.Hitbox.Size,
			HitboxOffset = AttackData.Hitbox and AttackData.Hitbox.Offset,

			Knockback = AttackData.Knockback,

			Feintable = Timing.Feintable,
			FeintEndlag = Timing.FeintEndlag,
			FeintCooldown = Timing.FeintCooldown,
			ComboEndlag = Timing.ComboEndlag,
			ComboResetTime = Timing.ComboResetTime,
			StaminaCostHitReduction = Timing.StaminaCostHitReduction,

			FallbackHitStart = Timing.FallbackHitStart,
			FallbackHitEnd = Timing.FallbackHitEnd,
			FallbackLength = Timing.FallbackLength,

			Flag = AttackData.Flag,
			Flags = AttackData.Flags,
		}
	end
end

function MetadataBuilders.SingleAttack(ComboKey: string, ActionName: string)
	return function(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
		local StyleName = StyleResolver.GetEntityStyle(Entity, InputData)
		if not StyleName then
			return nil
		end

		local AttackData = StyleConfig.GetAttack(StyleName, ComboKey, 1)
		local Timing = StyleConfig.GetTiming(StyleName)

		if not AttackData then
			return nil
		end

		local Modifiers = StyleResolver.GetModifiers(Entity, InputData)

		return {
			ActionName = ActionName,
			ActionType = "Attack",
			AnimationSet = StyleName,
			AnimationId = AttackData.AnimationId,

			Damage = StyleResolver.ApplyModifier(AttackData.Damage, Modifiers and Modifiers.DamageMultiplier),
			StaminaCost = StyleResolver.ApplyModifier(AttackData.StaminaCost, Modifiers and Modifiers.StaminaCostMultiplier),
			HitStun = AttackData.HitStun,

			HitboxSize = AttackData.Hitbox and AttackData.Hitbox.Size,
			HitboxOffset = AttackData.Hitbox and AttackData.Hitbox.Offset,

			Knockback = AttackData.Knockback,

			Feintable = Timing.Feintable,
			FeintEndlag = Timing.FeintEndlag,
			FeintCooldown = Timing.FeintCooldown,
			ActionCooldown = Timing.HeavyAttackCooldown,
			StaminaCostHitReduction = Timing.StaminaCostHitReduction,

			FallbackHitStart = Timing.FallbackHitStart,
			FallbackHitEnd = Timing.FallbackHitEnd,
			FallbackLength = Timing.FallbackLength,

			Flag = AttackData.Flag,
			Flags = AttackData.Flags,
		}
	end
end

function MetadataBuilders.CounterAttack(ActionName: string, DamageMultiplier: number?)
	local FinalMultiplier = DamageMultiplier or 1.0

	return function(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
		local StyleName = StyleResolver.GetEntityStyleOrDefault(Entity, InputData)
		local ComboLength = StyleConfig.GetComboLength(StyleName, "M1")
		local AttackData = StyleConfig.GetAttack(StyleName, "M1", ComboLength)
		local Timing = StyleConfig.GetTiming(StyleName)

		if not AttackData then
			AttackData = StyleConfig.GetAttack("Fists", "M1", 4)
		end

		if not AttackData then
			return nil
		end

		return {
			ActionName = ActionName,
			ActionType = "Attack",
			AnimationSet = StyleName,
			AnimationId = AttackData.AnimationId,

			Damage = math.floor((AttackData.Damage or 10) * FinalMultiplier),
			HitStun = AttackData.HitStun or 0.4,
			Knockback = AttackData.Knockback or 40,

			HitboxSize = AttackData.Hitbox and AttackData.Hitbox.Size or Vector3.new(6, 5, 7),
			HitboxOffset = AttackData.Hitbox and AttackData.Hitbox.Offset or Vector3.new(0, 0, -4),

			FallbackHitStart = Timing.FallbackHitStart or 0.2,
			FallbackHitEnd = Timing.FallbackHitEnd or 0.5,
			FallbackLength = Timing.FallbackLength or 1.0,
		}
	end
end

function MetadataBuilders.Static(Metadata: ActionMetadata)
	return function(_Entity: Entity, _InputData: { [string]: any }?): ActionMetadata?
		return table.clone(Metadata)
	end
end

function MetadataBuilders.Extend(BaseBuilder: (Entity: Entity, InputData: { [string]: any }?) -> ActionMetadata?, Extensions: { [string]: any })
	return function(Entity: Entity, InputData: { [string]: any }?): ActionMetadata?
		local BaseMetadata = BaseBuilder(Entity, InputData)
		if not BaseMetadata then
			return nil
		end

		for Key, Value in Extensions do
			BaseMetadata[Key] = Value
		end

		return BaseMetadata
	end
end

return MetadataBuilders