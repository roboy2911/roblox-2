-- Enemy types and where they spawn. Numbers are a starting point; tune here.

local Enemies = {}

Enemies.Types = {
	Rat = {
		DisplayName = "Rat",
		Model = "Rat", -- key in Config/Assets
		Level = 3,
		MaxHealth = 80,
		Defense = 0,
		Length = 3.6, -- studs from nose to tail tip
		WalkSpeed = 15,
		WanderSpeed = 6,

		AggroRange = 22, -- notices players this close
		LeashRange = 50, -- gives up if dragged this far from its spawn area
		AttackRange = 4.5,
		AttackDamage = 6,
		AttackWindup = 0.4, -- rears back for this long before biting (time to dodge)
		AttackCooldown = 1.6,

		XP = 30,
		Gold = { 8, 14 }, -- random between these
		RespawnTime = 15,
	},
}

-- Fixed spawn areas. Center is on the ground (Y is found automatically).
Enemies.SpawnAreas = {
	{
		Name = "Rat Field",
		Enemy = "Rat",
		Center = Vector3.new(-60, 0, 10),
		Radius = 16,
		Count = 5,
	},
}

return Enemies
