--!strict

export type SoundIdList = { string }
export type SoundIdsByMaterialName = { [string]: SoundIdList }

local FootstepSoundCatalog = {}

local FootstepSoundGroups = {
	GeneralRock = "rbxassetid://18984787734",
	GeneralGranite = "rbxassetid://78958298131160",
	GeneralGrass = "rbxassetid://7003103812",
	GeneralWood = "rbxassetid://95897689644876",
	GeneralMetal = "rbxassetid://113703432248314",
	GeneralTile = "rbxassetid://78958298131160",
	GeneralSoft = "rbxassetid://75216555975721",
	GeneralPlastic = "rbxassetid://267454199",
	GeneralFabric = "rbxassetid://151760062",
	GeneralConcrete = "rbxassetid://18984787734",
}

local SoundIdsByMaterialNameValue: SoundIdsByMaterialName = {
	Grass = { FootstepSoundGroups.GeneralGrass },
	LeafyGrass = { FootstepSoundGroups.GeneralGrass },
	Mud = { "rbxassetid://6441160246" },
	Salt = { FootstepSoundGroups.GeneralSoft },
	Sand = { FootstepSoundGroups.GeneralSoft },
	Snow = { FootstepSoundGroups.GeneralSoft },
	Ground = { "rbxassetid://6540746817" },

	Wood = { FootstepSoundGroups.GeneralWood },
	WoodPlanks = { FootstepSoundGroups.GeneralWood },
	Cardboard = { FootstepSoundGroups.GeneralWood },
	Plaster = { FootstepSoundGroups.GeneralWood },
	RoofShingles = { FootstepSoundGroups.GeneralWood },

	Carpet = { FootstepSoundGroups.GeneralFabric },
	Fabric = { FootstepSoundGroups.GeneralFabric },
	Leather = { FootstepSoundGroups.GeneralFabric },

	Plastic = { FootstepSoundGroups.GeneralPlastic },
	SmoothPlastic = { FootstepSoundGroups.GeneralPlastic },
	Neon = { FootstepSoundGroups.GeneralPlastic },
	Rubber = { FootstepSoundGroups.GeneralPlastic },
	ForceField = { FootstepSoundGroups.GeneralPlastic },

	Basalt = { FootstepSoundGroups.GeneralRock },
	CrackedLava = { FootstepSoundGroups.GeneralRock },
	Glacier = { FootstepSoundGroups.GeneralRock },
	Granite = { FootstepSoundGroups.GeneralGranite },
	Limestone = { FootstepSoundGroups.GeneralRock },
	Rock = { FootstepSoundGroups.GeneralRock },
	Sandstone = { FootstepSoundGroups.GeneralRock },

	Asphalt = { FootstepSoundGroups.GeneralConcrete },
	Concrete = { FootstepSoundGroups.GeneralConcrete },
	Pavement = { FootstepSoundGroups.GeneralConcrete },
	Road = { FootstepSoundGroups.GeneralConcrete },

	CeramicTiles = { FootstepSoundGroups.GeneralTile },
	Glass = { FootstepSoundGroups.GeneralTile },
	Slate = { FootstepSoundGroups.GeneralTile },
	Brick = { "rbxassetid://168786259" },
	Cobblestone = { "rbxassetid://142548009" },
	ClayRoofTiles = { "rbxassetid://9117382868" },

	Metal = { FootstepSoundGroups.GeneralMetal },
	CorrodedMetal = { FootstepSoundGroups.GeneralMetal },
	DiamondPlate = { "rbxassetid://481216891" },
	Foil = { "rbxassetid://142431247" },

	Ice = { "rbxassetid://19326880" },
	Marble = { "rbxassetid://134464111" },
	Pebble = { "rbxassetid://180239547" },
	Splash = { "rbxassetid://28604165" },
}

function FootstepSoundCatalog.GetSoundIdsByMaterialName(): SoundIdsByMaterialName
	return SoundIdsByMaterialNameValue
end

function FootstepSoundCatalog.GetRandomSoundId(MaterialName: string): string?
	local SoundIdList = SoundIdsByMaterialNameValue[MaterialName]
	if not SoundIdList or #SoundIdList == 0 then
		return nil
	end

	local Index = math.random(1, #SoundIdList)
	return SoundIdList[Index]
end

return FootstepSoundCatalog
