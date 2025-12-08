--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local AtomicBinding = require(script:WaitForChild("AtomicBinding"))

type Playable = Sound | AudioPlayer

local function LoadFlag(flag: string)
	local Success, Result = pcall(function()
		return UserSettings():IsUserFeatureEnabled(flag)
	end)
	return Success and Result
end

local FFlagUserSoundsUseRelativeVelocity = LoadFlag('UserSoundsUseRelativeVelocity2')
local FFlagUserNewCharacterSoundsApi = LoadFlag('UserNewCharacterSoundsApi3')
local FFlagUserFixCharSoundsEmitters = LoadFlag('UserFixCharSoundsEmitters')

local SOUND_DATA : { [string]: {[string]: any}} = {
	Climbing = {
		SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		Looped = true,
	},
	Died = {
		SoundId = "rbxasset://sounds/uuhhh.mp3",
	},
	FreeFalling = {
		SoundId = "rbxasset://sounds/action_falling.ogg",
		Looped = true,
	},
	GettingUp = {
		SoundId = "rbxasset://sounds/action_get_up.mp3",
	},
	Jumping = {
		SoundId = "rbxasset://sounds/action_jump.mp3",
	},
	Landing = {
		SoundId = "rbxasset://sounds/action_jump_land.mp3",
	},
	Splash = {
		SoundId = "rbxasset://sounds/impact_water.mp3",
	},
	Swimming = {
		SoundId = "rbxasset://sounds/action_swim.mp3",
		Looped = true,
		Pitch = 1.6,
	},
}

local AUDIOPLAYER_DATA : { [string]: {[string]: any}} = {
	Climbing = {
		AssetId = "rbxasset://sounds/action_footsteps_plastic.mp3",
		Looping = true,
	},
	Died = {
		AssetId = "rbxasset://sounds/uuhhh.mp3",
	},
	FreeFalling = {
		AssetId = "rbxasset://sounds/action_falling.ogg",
		Looping = true,
	},
	GettingUp = {
		AssetId = "rbxasset://sounds/action_get_up.mp3",
	},
	Jumping = {
		AssetId = "rbxasset://sounds/action_jump.mp3",
	},
	Landing = {
		AssetId = "rbxasset://sounds/action_jump_land.mp3",
	},
	Splash = {
		AssetId = "rbxasset://sounds/impact_water.mp3",
	},
	Swimming = {
		AssetId = "rbxasset://sounds/action_swim.mp3",
		Looping = true,
		PlaybackSpeed = 1.6,
	},
}

local function Map(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return (x - inMin)*(outMax - outMin)/(inMax - inMin) + outMin
end

local function GetRelativeVelocity(controllerManager, velocity)
	if not controllerManager then
		return velocity
	end
	local ActiveSensor = controllerManager.ActiveController and
		(
			(controllerManager.ActiveController:IsA("GroundController") and controllerManager.GroundSensor) or
			(controllerManager.ActiveController:IsA("ClimbController") and controllerManager.ClimbSensor)
		)
	if ActiveSensor and ActiveSensor.SensedPart then
		local PlatformVelocity = ActiveSensor.SensedPart:GetVelocityAtPosition(controllerManager.RootPart.Position)
		return velocity - PlatformVelocity
	end
	return velocity
end

local function PlaySound(sound: Playable, continue: boolean?)
	if not continue then
		(sound :: any).TimePosition = 0
	end
	if FFlagUserNewCharacterSoundsApi and sound:IsA("AudioPlayer") then
		sound:Play()
	else
		(sound :: Sound).Playing = true
	end
end

local function StopSound(sound: Playable)
	if FFlagUserNewCharacterSoundsApi and sound:IsA("AudioPlayer") then
		sound:Stop()
	else
		(sound :: Sound).Playing = false
	end
end

local function PlaySoundIf(sound: Playable, condition: boolean)
	if FFlagUserNewCharacterSoundsApi and sound:IsA("AudioPlayer") then
		if (sound.IsPlaying and not condition) then
			sound:Stop()
		elseif (not sound.IsPlaying and condition) then
			sound:Play()
		end
	else
		(sound :: Sound).Playing = condition
	end
end

local function SetSoundLooped(sound: Playable, isLooped: boolean)
	if FFlagUserNewCharacterSoundsApi and sound:IsA("AudioPlayer") then
		sound.Looping = isLooped
	else
		(sound :: Sound).Looped = isLooped
	end
end

local function ShallowCopy(sourceTable)
	local OutputTable = {}
	for key, value in pairs(sourceTable) do
		OutputTable[key] = value
	end
	return OutputTable
end

local function InitializeSoundSystem(instances: { [string]: Instance })
	local Humanoid = instances.humanoid
	local RootPart = instances.rootPart
	local AudioEmitter = nil
	local ControllerManager = nil
	if FFlagUserSoundsUseRelativeVelocity then
		local Character = Humanoid.Parent
		ControllerManager = Character:FindFirstChild('ControllerManager')
	end

	local Sounds: {[string]: Playable} = {}

	if FFlagUserNewCharacterSoundsApi and SoundService.CharacterSoundsUseNewApi == Enum.RolloutState.Enabled then
		local LocalPlayer = nil
		local Character = nil
		local HumanoidRootPart = nil
		if FFlagUserFixCharSoundsEmitters then
			HumanoidRootPart = Humanoid.RootPart
		else
			LocalPlayer = Players.LocalPlayer
			Character = LocalPlayer.Character
		end
		local Curve = {}
		local Index : number = 5
		local Step : number = 1.25
		while Index < 150 do
			Curve[Index] = 5 / Index
			Index *= Step
		end
		Curve[150] = 0
		if FFlagUserFixCharSoundsEmitters then
			AudioEmitter = Instance.new("AudioEmitter", HumanoidRootPart)
		else
			AudioEmitter = Instance.new("AudioEmitter", Character)
		end
		AudioEmitter.Name = "RbxCharacterSoundsEmitter"
		AudioEmitter:SetDistanceAttenuation(Curve)

		for name: string, props: {[string]: any} in pairs(AUDIOPLAYER_DATA) do
			local Sound = Instance.new("AudioPlayer")
			local AudioPlayerWire: Wire = Instance.new("Wire")
			Sound.Name = name
			AudioPlayerWire.Name = name .. "Wire"
			Sound.Archivable = false
			Sound.Volume = 0.65
			for propName, propValue: any in pairs(props) do
				(Sound :: any)[propName] = propValue
			end
			Sound.Parent = RootPart
			AudioPlayerWire.Parent = Sound
			AudioPlayerWire.SourceInstance = Sound
			AudioPlayerWire.TargetInstance = AudioEmitter
			Sounds[name] = Sound
		end
	else
		for name: string, props: {[string]: any} in pairs(SOUND_DATA) do
			local Sound = Instance.new("Sound")
			Sound.Name = name
			Sound.Archivable = false
			Sound.RollOffMinDistance = 5
			Sound.RollOffMaxDistance = 150
			Sound.Volume = 0.65
			for propName, propValue: any in pairs(props) do
				(Sound :: any)[propName] = propValue
			end
			Sound.Parent = RootPart
			Sounds[name] = Sound
		end
	end

	local PlayingLoopedSounds: {[Playable]: boolean?} = {}

	local function StopPlayingLoopedSounds(except: Playable?)
		except = except or nil
		for sound in pairs(ShallowCopy(PlayingLoopedSounds)) do
			if sound ~= except then
				StopSound(sound)
				PlayingLoopedSounds[sound] = nil
			end
		end
	end

	local StateTransitions: {[Enum.HumanoidStateType]: () -> ()} = {
		[Enum.HumanoidStateType.FallingDown] = function()
			StopPlayingLoopedSounds()
		end,

		[Enum.HumanoidStateType.GettingUp] = function()
			StopPlayingLoopedSounds()
			PlaySound(Sounds.GettingUp)
		end,

		[Enum.HumanoidStateType.Jumping] = function()
			StopPlayingLoopedSounds()
			PlaySound(Sounds.Jumping)
		end,

		[Enum.HumanoidStateType.Swimming] = function()
			local VerticalSpeed = math.abs(RootPart.AssemblyLinearVelocity.Y)
			if VerticalSpeed > 0.1 then
				(Sounds.Splash :: any).Volume = math.clamp(Map(VerticalSpeed, 100, 350, 0.28, 1), 0, 1)
				PlaySound(Sounds.Splash)
			end
			StopPlayingLoopedSounds(Sounds.Swimming)
			PlaySound(Sounds.Swimming, true)
			PlayingLoopedSounds[Sounds.Swimming] = true
		end,

		[Enum.HumanoidStateType.Freefall] = function()
			(Sounds.FreeFalling :: any).Volume = 0
			StopPlayingLoopedSounds(Sounds.FreeFalling)

			SetSoundLooped(Sounds.FreeFalling, true)
			if Sounds.FreeFalling:IsA("Sound") then
				Sounds.FreeFalling.PlaybackRegionsEnabled = true
			end
			(Sounds.FreeFalling :: any).LoopRegion = NumberRange.new(2, 9)
			PlaySound(Sounds.FreeFalling)

			PlayingLoopedSounds[Sounds.FreeFalling] = true
		end,

		[Enum.HumanoidStateType.Landed] = function()
			StopPlayingLoopedSounds()
			local VerticalSpeed = math.abs(RootPart.AssemblyLinearVelocity.Y)
			if VerticalSpeed > 75 then
				(Sounds.Landing :: any).Volume = math.clamp(Map(VerticalSpeed, 50, 100, 0, 1), 0, 1)
				PlaySound(Sounds.Landing)
			end
		end,

		[Enum.HumanoidStateType.Running] = function()
			StopPlayingLoopedSounds()
		end,

		[Enum.HumanoidStateType.Climbing] = function()
			local Sound = Sounds.Climbing
			local PartVelocity = RootPart.AssemblyLinearVelocity
			local Velocity = if FFlagUserSoundsUseRelativeVelocity then GetRelativeVelocity(ControllerManager, PartVelocity) else PartVelocity

			if Humanoid.MoveDirection.Magnitude > 0.1 then
				if math.abs(Velocity.Y) > 0.1 then
					PlaySound(Sound, true)
					StopPlayingLoopedSounds(Sound)
					PlayingLoopedSounds[Sound] = true
				else
					StopPlayingLoopedSounds()
				end
			else
				StopPlayingLoopedSounds()
			end
		end,

		[Enum.HumanoidStateType.Seated] = function()
			StopPlayingLoopedSounds()
		end,

		[Enum.HumanoidStateType.Dead] = function()
			StopPlayingLoopedSounds()
			PlaySound(Sounds.Died)
		end,
	}

	local LoopedSoundUpdaters: {[Playable]: (number, Playable, Vector3) -> ()} = {
		[Sounds.Climbing] = function(deltaTime: number, sound: Playable, velocity: Vector3)
			local RelativeVelocity = if FFlagUserSoundsUseRelativeVelocity then GetRelativeVelocity(ControllerManager, velocity) else velocity
			local IsMoving = Humanoid.MoveDirection.Magnitude > 0.1
			local IsClimbing = math.abs(RelativeVelocity.Y) > 0.1
			PlaySoundIf(sound, IsMoving and IsClimbing)
		end,

		[Sounds.FreeFalling] = function(deltaTime: number, sound: Playable, velocity: Vector3): ()
			if velocity.Magnitude > 75 then
				(sound :: any).Volume = math.clamp((sound :: any).Volume + 0.9*deltaTime, 0, 1)
			else
				(sound :: any).Volume = 0
			end
		end,
	}

	local StateRemap: {[Enum.HumanoidStateType]: Enum.HumanoidStateType} = {
		[Enum.HumanoidStateType.RunningNoPhysics] = Enum.HumanoidStateType.Running,
	}

	local ActiveState: Enum.HumanoidStateType = StateRemap[Humanoid:GetState()] or Humanoid:GetState()

	local function TransitionTo(state)
		local TransitionFunc: () -> () = StateTransitions[state]

		if TransitionFunc then
			TransitionFunc()
		end

		ActiveState = state
	end

	TransitionTo(ActiveState)

	local StateChangedConnection = Humanoid.StateChanged:Connect(function(_, state)
		state = StateRemap[state] or state

		if state ~= ActiveState then
			TransitionTo(state)
		end
	end)

	local SteppedConnection = RunService.Stepped:Connect(function(_, worldDeltaTime: number)
		for sound in pairs(PlayingLoopedSounds) do
			local Updater: (number, Playable, Vector3) -> () = LoopedSoundUpdaters[sound]

			if Updater then
				Updater(worldDeltaTime, sound, RootPart.AssemblyLinearVelocity)
			end
		end

		if ActiveState == Enum.HumanoidStateType.Running and Sounds.Climbing then
			local ClimbingSound = Sounds.Climbing
			if (ClimbingSound:IsA("AudioPlayer") and ClimbingSound.IsPlaying) or 
				(ClimbingSound:IsA("Sound") and ClimbingSound.Playing) then
				StopSound(ClimbingSound)
				PlayingLoopedSounds[ClimbingSound] = nil
			end
		end
	end)

	local function Terminate()
		StateChangedConnection:Disconnect()
		SteppedConnection:Disconnect()

		for name: string, sound: Playable in pairs(Sounds) do
			sound:Destroy()
		end
		table.clear(Sounds)
	end

	return Terminate
end

local Binding = AtomicBinding.new({
	humanoid = "Humanoid",
	rootPart = "HumanoidRootPart",
}, InitializeSoundSystem)

local PlayerConnections = {}

local function CharacterAdded(character)
	Binding:bindRoot(character)
end

local function CharacterRemoving(character)
	Binding:unbindRoot(character)
end

local function PlayerAdded(player: Player)
	local Connections = PlayerConnections[player]
	if not Connections then
		Connections = {}
		PlayerConnections[player] = Connections
	end

	if player.Character then
		CharacterAdded(player.Character)
	end
	table.insert(Connections, player.CharacterAdded:Connect(CharacterAdded))
	table.insert(Connections, player.CharacterRemoving:Connect(CharacterRemoving))
end

local function PlayerRemoving(player: Player)
	local Connections = PlayerConnections[player]
	if Connections then
		for _, connection in ipairs(Connections) do
			connection:Disconnect()
		end
		PlayerConnections[player] = nil
	end

	if player.Character then
		CharacterRemoving(player.Character)
	end
end

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end
Players.PlayerAdded:Connect(PlayerAdded)
Players.PlayerRemoving:Connect(PlayerRemoving)