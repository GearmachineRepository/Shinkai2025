--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")

local Ensemble = require(Server.Ensemble)

task.wait(3)

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Entities = Assets:WaitForChild("Entity")
local TestDummy = Entities:WaitForChild("TestDummy")

local function SpawnTestDummy()
	local DummyCharacter = TestDummy:Clone()
	DummyCharacter.Parent = workspace.Characters

	local DummyEntity = Ensemble.CreateEntity(DummyCharacter, {})
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

            SpawnTestDummy()

            DummyDie:Disconnect()
        end)
    end
end

SpawnTestDummy()