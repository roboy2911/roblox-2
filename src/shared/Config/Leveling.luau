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
