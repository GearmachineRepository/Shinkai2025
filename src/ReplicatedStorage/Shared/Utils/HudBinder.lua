--!strict

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

export type HudRefs = {
	Hud: ScreenGui,
	Frames: Instance,
}

local HudBinder = {}

local CurrentHud: ScreenGui? = nil
local CurrentFrames: Instance? = nil

local ChangedEvent = Instance.new("BindableEvent")

function HudBinder.OnChanged(Callback: (HudRefs) -> ()): RBXScriptConnection
	return ChangedEvent.Event:Connect(Callback)
end

local function Resolve(): HudRefs?
	local Hud = PlayerGui:FindFirstChild("Hud")
	if not Hud or not Hud:IsA("ScreenGui") then
		return nil
	end

	local Frames = Hud:FindFirstChild("Frames")
	if not Frames then
		return nil
	end

	return {
		Hud = Hud,
		Frames = Frames,
	}
end

function HudBinder.Get(): HudRefs
	while true do
		local Refs = Resolve()
		if Refs then
			CurrentHud = Refs.Hud
			CurrentFrames = Refs.Frames
			return Refs
		end
		PlayerGui.ChildAdded:Wait()
	end
end

function HudBinder.IsValid(): boolean
	if not CurrentHud or CurrentHud.Parent == nil then
		return false
	end
	if not CurrentFrames or CurrentFrames.Parent == nil then
		return false
	end
	return true
end

task.spawn(function()
	while true do
		local Refs = HudBinder.Get()
		ChangedEvent:Fire(Refs)

		Refs.Hud.AncestryChanged:Wait()
	end
end)

return HudBinder
