-- Leveling numbers from the design doc. Tune here, not in the services.

local Leveling = {}

Leveling.MaxLevel = 300
Leveling.StatPointsPerLevel = 3

Leveling.BaseHealth = 100
Leveling.HealthPerVitality = 10

-- XP to next level = 100 + level x 25 (level 1 needs 125, level 100 needs 2,600).
function Leveling.XPToNext(level: number): number
	return 100 + level * 25
end

-- Stats a player can put points into. Order is the order shown in menus.
Leveling.StatNames = { "Strength", "Weapon", "GemPower", "Defense", "Vitality" }

-- What each stat does, for the stats menu.
Leveling.StatInfo = {
	Strength = { DisplayName = "Strength", Effect = "+1% combat style damage" },
	Weapon = { DisplayName = "Weapon", Effect = "+1% weapon damage" },
	GemPower = { DisplayName = "Gem Power", Effect = "+1% gem damage" },
	Defense = { DisplayName = "Defense", Effect = "-0.5% damage taken (max 50%)" },
	Vitality = { DisplayName = "Vitality", Effect = "+10 HP, +5 energy" },
}

-- Resetting stats gives all points back for gold.
function Leveling.ResetCost(level: number): number
	return 50 * level
end

-- What a brand new player starts with. New fields added here are filled in
-- for old saves automatically.
Leveling.DefaultData = {
	Level = 1,
	XP = 0,
	Gold = 0,
	StatPoints = 0,
	Stats = {
		Strength = 0,
		Weapon = 0,
		GemPower = 0,
		Defense = 0,
		Vitality = 0,
	},
	Quest = { Id = "", Progress = 0 }, -- active quest ("" = none)
	Gem = "", -- the gem you've eaten ("" = none)
	Style = "Brawler", -- combat style
	Weapon = "", -- equipped weapon ("" = none)
	OwnedWeapons = {}, -- [weaponId] = true
}

function Leveling.MaxHealth(vitality: number): number
	return Leveling.BaseHealth + vitality * Leveling.HealthPerVitality
end

return Leveling
