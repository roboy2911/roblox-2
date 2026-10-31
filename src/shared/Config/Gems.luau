-- Enchanted Gems: their moves, where they spawn, and what they cost.
-- Numbers are a starting point; tune here.

local Gems = {}

Gems.Energy = {
	Base = 100,
	PerVitality = 5,
	RegenPerSecond = 10,
}

Gems.List = {
	Ember = {
		DisplayName = "Ember Gem",
		Rarity = "Common",
		Color = Color3.fromRGB(255, 120, 30),
		Model = "EmberGem", -- key in Config/Assets Models
		Price = 5000, -- at the Gem Merchant
		Moves = {
			Z = {
				Name = "Fireball",
				Kind = "Projectile",
				Animation = "CastFireball",
				Fx = "Fire",
				Level = 1,
				Energy = 15,
				Cooldown = 3,
				Damage = 35,
				Speed = 90, -- studs per second
				Range = 120,
				BlastRadius = 7,
				Stun = 0.4,
				CastTime = 0.15, -- arm thrust before it flies
			},
			X = {
				Name = "Flame Dash",
				Kind = "Dash",
				Animation = "FlameDash",
				Fx = "Fire",
				Level = 25,
				Energy = 20,
				Cooldown = 6,
				Damage = 28,
				Distance = 32,
				DashTime = 0.28,
				HitWidth = 5, -- burns enemies within this distance of your path
				Stun = 0.5,
			},
			C = {
				Name = "Fire Ring",
				Kind = "Burst",
				Animation = "FireRing",
				Fx = "Fire",
				Hits = 1,
				Interval = 0,
				Level = 75,
				Energy = 40,
				Cooldown = 12,
				Damage = 70,
				Radius = 16,
				CastTime = 0.35, -- crouch before the blast
				Stun = 0.9,
			},
		},
	},
}

-- Gems that appear under trees around Millbrook.
Gems.TreeSpawn = {
	Gems = { "Ember" }, -- picked at random
	FirstSpawnDelay = 120, -- seconds after the server starts
	Interval = 3600, -- then once an hour
	Lifetime = 1200, -- disappears if nobody takes it in 20 minutes
}

-- Trees around Millbrook (ground positions; Y is found automatically).
Gems.Trees = {
	Vector3.new(-28, 0, -30),
	Vector3.new(30, 0, -34),
	Vector3.new(-36, 0, 48),
	Vector3.new(38, 0, 54),
	Vector3.new(-12, 0, -48),
	Vector3.new(52, 0, -10),
	Vector3.new(-30, 0, 18),
	Vector3.new(20, 0, 70),
}

Gems.Merchant = {
	DisplayName = "Gem Merchant Zara",
	Greeting = "Shiny stones with a little fire in them. Interested?",
	Position = Vector3.new(26, 0, -10),
	Stock = { "Ember" },
}

return Gems
