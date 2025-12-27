local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local VfxPlayer = require(Shared.VFX.VfxPlayer)

VfxPlayer.Init()