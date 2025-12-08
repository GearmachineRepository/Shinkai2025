--!strict

local ClanTypes = require(script.Parent.Parent.Enums.ClanTypes)

-- local CommonClanData = {
-- 	Name = "",
-- 	RarityWeight = 64,
-- 	Description = "A common clan with no special abilities.",
-- 	UnlockedMode = nil,
-- 	UnlockedStyles = {},
-- 	StatBonuses = {},
-- 	Hooks = {},
-- }

local ClanDefinitions = {
	[ClanTypes.BROWN] = {
		Name = "Brown",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.SMITH] = {
		Name = "Smith",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.JONES] = {
		Name = "Jones",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.MILLER] = {
		Name = "Miller",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.CLARENCE] = {
		Name = "Clarence",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.DONALDA] = {
		Name = "Donalda",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.NICHOLAS] = {
		Name = "Nicholas",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.SEBASTIAN] = {
		Name = "Sebastian",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.TYSON] = {
		Name = "Tyson",
		RarityWeight = 64,
		Description = "A common clan with no special abilities.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.IMAI] = {
		Name = "Imai",
		RarityWeight = 4,
		Description = "Imai clan allows the player to learn Zōn.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		UnlockedSkills = {"Zon"},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.REINHOLD] = {
		Name = "Reinhold",
		RarityWeight = 4,
		Description = "The reinhold clan gives the player an extra star worth of muscle, along with a slight height boost.",
		UnlockedMode = nil,
		UnlockedStyles = {},
		StatBonuses = {
			Muscle = 20,
		},
		Hooks = {"ReinholdHeight"},
	},

	[ClanTypes.WONGSAWAT] = {
		Name = "Wongsawat",
		RarityWeight = 4,
		Description = "The wongsawat clan buffs Muay Thai's pure, giving it more damage. The player is also able to learn the skill God Glow.",
		UnlockedMode = nil,
		UnlockedStyles = {"MuayThai"},
		UnlockedSkills = {"GoddoGuro"},
		StatBonuses = {},
		Hooks = {"WongsawatMuayThaiBoost"},
	},

	[ClanTypes.KURE] = {
		Name = "Kure",
		RarityWeight = 1,
		Description = "The kure clan utilizes Removal. Starting percentage is 5%, max for regular players is 75%. Gives access to the Kure style.",
		UnlockedMode = "Removal",
		UnlockedStyles = {"Kure"},
		StatBonuses = {},
		Hooks = {},
		ModeConfig = {
			RemovalStartPercent = 5,
			RemovalMaxPercent = 75,
		},
	},

	[ClanTypes.MIKAZUCHI] = {
		Name = "Mikazuchi",
		RarityWeight = 1,
		Description = "The mikazuchi clan comes with a passive of extra 2% run speed and 1.5% passive speed increase on m1s. Gives access to the Raishin style.",
		UnlockedMode = nil,
		UnlockedStyles = {"Raishin"},
		StatBonuses = {
			RunSpeed = 4,
		},
		Hooks = {"MikazuchiSpeed"},
	},

	[ClanTypes.GAOH] = {
		Name = "Gaoh",
		RarityWeight = 1,
		Description = "Gaoh clan gives access to the Gaoh style.",
		UnlockedMode = nil,
		UnlockedStyles = {"Gaoh"},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.OHMA] = {
		Name = "Ohma",
		RarityWeight = 0.64,
		Description = "The Ohma clan gives the player access to the mode called Advance and the Niko style along with its skills.",
		UnlockedMode = "Advance",
		UnlockedStyles = {"Niko"},
		StatBonuses = {},
		Hooks = {},
	},

	[ClanTypes.WU] = {
		Name = "Wu",
		RarityWeight = 0.64,
		Description = "The Wu clan gives access to the kure style and techniques along with extra wu-exclusive moves and the ability to unlock a higher cap of removal, otherwise called Guihan.",
		UnlockedMode = "Guihan",
		UnlockedStyles = {"Kure", "Wu"},
		UnlockedSkills = {"Hachikaiken", "Jusansatsuken"},
		StatBonuses = {},
		Hooks = {},
		ModeConfig = {
			RemovalStartPercent = 5,
			RemovalMaxPercent = 100,
		},
	},
}

return {
	Types = ClanTypes,
	Definitions = ClanDefinitions,
}