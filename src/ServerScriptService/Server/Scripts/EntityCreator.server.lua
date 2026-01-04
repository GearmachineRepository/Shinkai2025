--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)

task.wait(3)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Entities = Assets:WaitForChild("Entity")
local TestDummyAttacker = Entities:WaitForChild("TestDummyAttacker")
local TestDummyAttackingUnanchored = Entities:WaitForChild("TestDummyAttackingUnanchored")
local TestDummyIdleUnanchored = Entities:WaitForChild("TestDummyIdleUnanchored")
local TestDummyIdleAnchored = Entities:WaitForChild("TestDummyIdle")
local TestDummyBlocker = Entities:WaitForChild("TestDummyBlocker")

local ATTACKING_DUMMY_CONFIG = {
	Combat = {
		ToolId = "Karate",
		AttackRange = 6,
		AggroRange = 30,
		AutoAttack = true,
		AttackIntervalMin = 0.1,
		AttackIntervalMax = 0.1,
	},
}

local BLOCKING_DUMMY_CONFIG = {
	Combat = {
		ToolId = "Karate",
		AttackRange = 6,
		AggroRange = 30,
		AutoAttack = false,
	},
}

local function SpawnAttackingDummy()
	local DummyCharacter = TestDummyAttacker:Clone()
	DummyCharacter.Parent = workspace.Characters

	local DummyEntity = Ensemble.CreateEntity(DummyCharacter, ATTACKING_DUMMY_CONFIG)
		:WithArchetype("Entity")
		:Build()

	if not DummyEntity then
		return
	end

	local DummyDie do
		DummyDie = DummyEntity.Humanoid.Died:Once(function()
			task.wait(2)
			Ensemble.DestroyEntity(DummyCharacter)
			DummyCharacter:Destroy()

			SpawnAttackingDummy()

			DummyDie:Disconnect()
		end)
	end
end

local function SpawnAttackingUnanchoredDummy()
	local DummyCharacter = TestDummyAttackingUnanchored:Clone()
	DummyCharacter.Parent = workspace.Characters

	local DummyEntity = Ensemble.CreateEntity(DummyCharacter, ATTACKING_DUMMY_CONFIG)
		:WithArchetype("Entity")
		:Build()

	if not DummyEntity then
		return
	end

	local DummyDie do
		DummyDie = DummyEntity.Humanoid.Died:Once(function()
			task.wait(2)
			Ensemble.DestroyEntity(DummyCharacter)
			DummyCharacter:Destroy()

			SpawnAttackingUnanchoredDummy()

			DummyDie:Disconnect()
		end)
	end
end

local function SpawnBlockingDummy()
	local DummyCharacter = TestDummyBlocker:Clone()
	DummyCharacter.Parent = workspace.Characters

	local DummyEntity = Ensemble.CreateEntity(DummyCharacter, BLOCKING_DUMMY_CONFIG)
		:WithArchetype("Entity")
		:Build()

	if not DummyEntity then
		return
	end

	local IsAlive = true

	task.spawn(function()
		while IsAlive do
			local NpcCombat = DummyEntity:GetComponent("NpcCombat")
			if NpcCombat and NpcCombat:CanAct() then
				NpcCombat:Block()
			end
			task.wait(0.2)
		end
	end)

	local DummyDie do
		DummyDie = DummyEntity.Humanoid.Died:Once(function()
			IsAlive = false
			task.wait(2)
			Ensemble.DestroyEntity(DummyCharacter)
			DummyCharacter:Destroy()

			SpawnBlockingDummy()

			DummyDie:Disconnect()
		end)
	end
end

local function SpawnIdleDummy()
	local DummyCharacter = TestDummyIdleUnanchored:Clone()
	DummyCharacter.Parent = workspace.Characters

	local DummyEntity = Ensemble.CreateEntity(DummyCharacter, ATTACKING_DUMMY_CONFIG)
		:WithArchetype("Entity")
		:WithoutComponent("NpcCombat")
		:Build()

	if not DummyEntity then
		return
	end

	local DummyDie do
		DummyDie = DummyEntity.Humanoid.Died:Once(function()
			task.wait(2)
			Ensemble.DestroyEntity(DummyCharacter)
			DummyCharacter:Destroy()

			SpawnAttackingUnanchoredDummy()

			DummyDie:Disconnect()
		end)
	end
end

local function SpawnIdleDummyAnchored()
	local DummyCharacter = TestDummyIdleAnchored:Clone()
	DummyCharacter.Parent = workspace.Characters

	local DummyEntity = Ensemble.CreateEntity(DummyCharacter, ATTACKING_DUMMY_CONFIG)
		:WithArchetype("Entity")
		:WithoutComponent("NpcCombat")
		:Build()

	if not DummyEntity then
		return
	end

	local DummyDie do
		DummyDie = DummyEntity.Humanoid.Died:Once(function()
			task.wait(2)
			Ensemble.DestroyEntity(DummyCharacter)
			DummyCharacter:Destroy()

			SpawnAttackingUnanchoredDummy()

			DummyDie:Disconnect()
		end)
	end
end

SpawnAttackingDummy()
SpawnAttackingUnanchoredDummy()
SpawnBlockingDummy()
SpawnIdleDummy()
SpawnIdleDummyAnchored()