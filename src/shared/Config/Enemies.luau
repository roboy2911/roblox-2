-- Enemy types and where they spawn. Numbers are a starting point; tune here.

local Enemies = {}

Enemies.Types = {
	Rat = {
		DisplayName = "Rat",
		Model = "Rat", -- key in Config/Assets Models
		Rig = "Quadruped",
		BodyPart = "Body",
		Length = 3.6, -- studs from nose to tail tip
		Level = 3,
		MaxHealth = 80,
		Defense = 0,
		WalkSpeed = 15,
		WanderSpeed = 6,

		AggroRange = 22, -- notices players this close
		LeashRange = 50, -- gives up if dragged this far from its spawn area
		AttackRange = 4.5,
		AttackDamage = 6,
		AttackWindup = 0.4, -- warning time before the attack lands (time to dodge)
		AttackCooldown = 1.6,
		Knockback = 1,

		XP = 30,
		Gold = { 8, 14 }, -- random between these
		RespawnTime = 15,
	},

	BanditThug = {
		DisplayName = "Bandit Thug",
		Model = "BanditThug",
		Rig = "Biped",
		BodyPart = "Torso",
		Height = 5.6,
		Level = 12,
		MaxHealth = 260,
		Defense = 10,
		WalkSpeed = 14,
		WanderSpeed = 6,

		AggroRange = 24,
		LeashRange = 55,
		AttackRange = 6,
		AttackDamage = 14,
		AttackWindup = 0.55, -- raises the sword, then slashes
		AttackCooldown = 1.9,
		Knockback = 0.6, -- heavier than a rat

		XP = 110,
		Gold = { 25, 40 },
		RespawnTime = 15,
	},

	-- First boss. Attacks follow Pattern in order, then repeat:
	--   Cleave: a wide slash in front (red area shows where)
	--   Slam:   leaps onto the target's spot and smashes the ground (red circle)
	BanditCaptain = {
		DisplayName = "Bandit Captain",
		Model = "BanditCaptain",
		Rig = "Biped",
		BodyPart = "Torso",
		Height = 8,
		Level = 25,
		MaxHealth = 2500,
		Defense = 20,
		WalkSpeed = 13,
		WanderSpeed = 5,

		AggroRange = 30,
		LeashRange = 45,
		AttackRange = 9, -- how close he walks before attacking
		AttackDamage = 25,
		AttackWindup = 0.7,
		AttackCooldown = 1.3,
		Knockback = 0.1,

		Boss = true, -- big HP bar at the top of the screen; hits don't stun or interrupt him
		Pattern = { "Cleave", "Cleave", "Slam" },
		Attacks = {
			Cleave = { Windup = 0.75, Range = 9, Radius = 11, Arc = -0.1, Damage = 25 },
			Slam = { Windup = 0.5, LeapTime = 0.75, Range = 34, Radius = 11, Damage = 35 },
		},

		XP = 1500,
		Gold = { 400, 600 },
		RespawnTime = 600, -- 10 minutes
	},
}

-- Fixed spawn areas. Center is on the ground (Y is found automatically).
-- Props are scattered around the edge; CenterProp sits in the middle.
Enemies.SpawnAreas = {
	{
		Name = "Rat Field",
		Enemy = "Rat",
		Center = Vector3.new(-60, 0, 10),
		Radius = 16,
		Count = 5,
		Props = { "HayBale", "Barrel", "HayBale", "Crate", "HayBale", "Barrel", "HayBale" },
	},
	{
		Name = "Bandit Camp",
		Enemy = "BanditThug",
		Center = Vector3.new(75, 0, 15),
		Radius = 18,
		Count = 5,
		Props = { "Tent", "Crate", "Barrel", "Tent", "Crate", "Crate", "Tent", "Barrel" },
		CenterProp = "Campfire",
	},
	{
		Name = "Captain's Clearing",
		Enemy = "BanditCaptain",
		Center = Vector3.new(122, 0, 15),
		Radius = 6,
		Count = 1,
		Props = { "Tent", "Crate", "Barrel", "Crate", "Tent", "Barrel" },
	},
}

return Enemies
