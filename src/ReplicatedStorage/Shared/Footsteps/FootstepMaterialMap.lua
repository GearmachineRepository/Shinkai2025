--!strict
-- Shared/Footsteps/FootstepMaterialMap.lua

local FootstepMaterialMap = {}

export type MaterialId = number

local MaterialNameToId: { [string]: MaterialId } = {
	WoodPlanks = 1,
	Wood = 2,
	CeramicTiles = 3,
	Splash = 4,
	Sand = 5,
	Plastic = 6,
	Pebble = 7,
	Metal = 8,
	Marble = 9,
	Ice = 10,
	Grass = 11,
	Granite = 12,
	Foil = 13,
	Fabric = 14,
	Diamond = 15,
	CorrodedMetal = 16,
	Concrete = 17,
	Cobblestone = 18,
	Brick = 19,
	Asphalt = 20,
	Basalt = 21,
	Rock = 22,
	Limestone = 23,
	Pavement = 24,
	Salt = 25,
	Sandstone = 26,
	Slate = 27,
	CrackedLava = 28,
	Neon = 29,
	Glass = 30,
	ForceField = 31,
	LeafyGrass = 32,
	Mud = 33,
	Snow = 34,
	Ground = 35,
	Cardboard = 36,
	Carpet = 37,
	Rubber = 38,
	Leather = 39,
	Road = 40,
}

local IdToMaterialName: { [MaterialId]: string } = {}
for MaterialName, MaterialId in MaterialNameToId do
	IdToMaterialName[MaterialId] = MaterialName
end

function FootstepMaterialMap.GetId(MaterialName: string): MaterialId?
	return MaterialNameToId[MaterialName]
end

function FootstepMaterialMap.GetName(MaterialId: MaterialId): string?
	return IdToMaterialName[MaterialId]
end

function FootstepMaterialMap.GetAllNames(): { string }
	local Names: { string } = {}
	for MaterialName in MaterialNameToId do
		table.insert(Names, MaterialName)
	end
	table.sort(Names)
	return Names
end

return FootstepMaterialMap
