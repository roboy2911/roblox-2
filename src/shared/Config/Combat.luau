-- Combat numbers from the design doc. Tune here, not in the services.
--
-- Every build slot (combat style, weapon, gem) has:
--   a click combo: Combo, Range, HitArc, cooldowns, Stat
--   moves on Z / X (gems also have C), each with a Kind:
--     Flurry      hits in front of you Hits times, Interval apart, after Delay
--     Dash        rush forward Distance studs, hitting what you pass
--     Burst       hits all around you Hits times, Interval apart, after CastTime
--     Projectile  flies toward your aim and explodes (gems)
--   Fx picks the look of the effects: "Fire", "Dust", "Steel", "Wind", "Slam".

local Combat = {}

-- Combat styles ----------------------------------------------------------------

Combat.Styles = {
	Brawler = {
		DisplayName = "Brawler",
		Stat = "Strength", -- stat that boosts this style's damage
		-- HitDelay: seconds from click to the hit landing (matches the animation).
		-- Lunge: how far forward the player steps into the hit.
		Combo = {
			{ Damage = 12, Animation = "JabRight", HitDelay = 0.1, LungeSpeed = 22, LungeTime = 0.08 },
			{ Damage = 12, Animation = "JabLeft", HitDelay = 0.1, LungeSpeed = 22, LungeTime = 0.08 },
			{ Damage = 18, Animation = "UppercutRight", HitDelay = 0.2, LungeSpeed = 42, LungeTime = 0.14, Heavy = true },
		},
		Range = 6, -- studs in front of the player
		AimAssistRange = 12, -- clicking turns you toward a target this close
		HitArc = 0.3, -- dot product with look direction; 0.3 is about a 145 degree cone
		SwingCooldown = 0.35,
		ComboEndCooldown = 0.8,
		ComboResetTime = 1.2, -- combo starts over if you wait this long
		Stun = 0.3, -- combo hits stun for 0.3 seconds
		Moves = {
			Z = {
				Name = "Punch Flurry", Kind = "Flurry", Animation = "PunchFlurry", Fx = "Dust",
				Level = 1, Energy = 10, Cooldown = 5,
				Damage = 9, Hits = 5, Delay = 0.1, Interval = 0.09, Range = 6.5, Arc = 0.3, Stun = 0.25,
			},
			X = {
				Name = "Shoulder Charge", Kind = "Dash", Animation = "ShoulderCharge", Fx = "Dust",
				Level = 1, Energy = 12, Cooldown = 7,
				Damage = 30, Distance = 16, DashTime = 0.25, HitWidth = 4, Stun = 0.6, Heavy = true,
			},
		},
	},
}

Combat.DefaultStyle = "Brawler"

-- Clicking with your gem slot selected: the Brawler combo with fire on your
-- fists, boosted by Gem Power instead of Strength.
Combat.GemPunches = table.clone(Combat.Styles.Brawler)
Combat.GemPunches.DisplayName = "Fire Fists"
Combat.GemPunches.Stat = "GemPower"
Combat.GemPunches.Fire = true
Combat.GemPunches.Moves = nil -- the gem's own moves are used instead

-- Weapons ----------------------------------------------------------------------
-- Grip: studs from the bottom of the model to where the hand holds it.
-- Length: how long the model is in the game.

Combat.Weapons = {
	IronSword = {
		DisplayName = "Iron Sword",
		Description = "A balanced blade. Quick slashes.",
		Price = 500,
		Model = "IronSword",
		Length = 4.4,
		Grip = 0.55,
		Stat = "Weapon",
		Combo = {
			{ Damage = 16, Animation = "SwordSlash1", HitDelay = 0.15, LungeSpeed = 20, LungeTime = 0.08 },
			{ Damage = 16, Animation = "SwordSlash2", HitDelay = 0.15, LungeSpeed = 20, LungeTime = 0.08 },
			{ Damage = 24, Animation = "SwordSlash3", HitDelay = 0.24, LungeSpeed = 36, LungeTime = 0.12, Heavy = true },
		},
		Range = 7.5,
		AimAssistRange = 13,
		HitArc = 0.15,
		SwingCooldown = 0.4,
		ComboEndCooldown = 0.85,
		ComboResetTime = 1.2,
		Stun = 0.3,
		Moves = {
			Z = {
				Name = "Slash Combo", Kind = "Flurry", Animation = "SwordFlurry", Fx = "Steel",
				Level = 1, Energy = 10, Cooldown = 5,
				Damage = 18, Hits = 3, Delay = 0.12, Interval = 0.15, Range = 8, Arc = 0.1, Stun = 0.35,
			},
			X = {
				Name = "Lunge", Kind = "Dash", Animation = "SwordLunge", Fx = "Steel",
				Level = 1, Energy = 15, Cooldown = 7,
				Damage = 40, Distance = 20, DashTime = 0.22, HitWidth = 4, Stun = 0.6,
			},
		},
	},
	BattleAxe = {
		DisplayName = "Battle Axe",
		Description = "Slow and heavy. Hits everything in front of you.",
		Price = 5000,
		Model = "BattleAxe",
		Length = 4.8,
		Grip = 0.7,
		Stat = "Weapon",
		Combo = {
			{ Damage = 28, Animation = "AxeSwing1", HitDelay = 0.26, LungeSpeed = 14, LungeTime = 0.08 },
			{ Damage = 28, Animation = "AxeSwing2", HitDelay = 0.26, LungeSpeed = 14, LungeTime = 0.08 },
			{ Damage = 45, Animation = "AxeSlam", HitDelay = 0.32, LungeSpeed = 20, LungeTime = 0.1, Heavy = true },
		},
		Range = 8.5,
		AimAssistRange = 13,
		HitArc = 0, -- everything in front (180 degrees)
		SwingCooldown = 0.6,
		ComboEndCooldown = 1.1,
		ComboResetTime = 1.5,
		Stun = 0.45,
		Moves = {
			Z = {
				Name = "Overhead Chop", Kind = "Flurry", Animation = "AxeChop", Fx = "Slam",
				Level = 1, Energy = 15, Cooldown = 6,
				Damage = 75, Hits = 1, Delay = 0.4, Interval = 0, Range = 9, Arc = 0.4, Stun = 0.8, Heavy = true,
			},
			X = {
				Name = "Whirlwind", Kind = "Burst", Animation = "AxeSpin", Fx = "Wind",
				Level = 1, Energy = 20, Cooldown = 9,
				Damage = 22, Hits = 3, CastTime = 0.19, Interval = 0.18, Radius = 9, Stun = 0.3,
			},
		},
	},
}

Combat.Blacksmith = {
	DisplayName = "Blacksmith Torvin",
	Greeting = "Need something sharp? Everything here is forged right in Millbrook.",
	Position = Vector3.new(6, 0, -20),
	Stock = { "IronSword", "BattleAxe" },
}

-- Damage = base x (1 + 1% per stat point) x (1 - defense reduction).
-- Defense: -0.5% damage taken per point, capped at 50%.
function Combat.CalculateDamage(base: number, statPoints: number, defensePoints: number): number
	local reduction = math.min(0.5, defensePoints * 0.005)
	return math.floor(base * (1 + statPoints * 0.01) * (1 - reduction) + 0.5)
end

return Combat
