--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")

local SoundPlayer = {}

function SoundPlayer.Play(Character: Model, SoundName: string)
	local TemplateSound = Sounds:FindFirstChild(SoundName) :: Sound?
	if not TemplateSound or not TemplateSound:IsA("Sound") then
		warn("Sound not found in Assets/Sounds:", SoundName)
		return
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then
		return
	end

	local SoundClone = TemplateSound:Clone()
	SoundClone.Parent = HumanoidRootPart
	SoundClone:Play()

	SoundClone.Ended:Connect(function()
		SoundClone:Destroy()
	end)

	return SoundClone
end

return SoundPlayer
