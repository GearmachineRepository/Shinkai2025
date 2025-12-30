--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage:WaitForChild("Assets")
local Sounds = Assets:WaitForChild("Sounds")

local SoundPlayer = {}

function SoundPlayer.Play(Character: Model, SoundReference: string | Sound)
	local TemplateSound = nil :: Sound?

	if typeof(SoundReference) == "string" then
		TemplateSound = Sounds:FindFirstChild(SoundReference, true) :: Sound?
	else
		TemplateSound = SoundReference
	end

	if not TemplateSound or not TemplateSound:IsA("Sound") then
		warn("Sound not found in Assets/Sounds:", SoundReference)
		return
	end

	local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not HumanoidRootPart then
		return
	end

	local SoundClone = TemplateSound:Clone()
	SoundClone.Parent = HumanoidRootPart
	SoundClone.PlaybackSpeed += math.random()/10
	SoundClone:Play()

	SoundClone.Ended:Connect(function()
		SoundClone:Destroy()
	end)

	return SoundClone
end

return SoundPlayer
