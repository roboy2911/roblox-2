-- Quest givers and their quests. Rewards follow the design doc: about
-- 1.5x the XP of the kills, plus gold.

local Quests = {}

Quests.Givers = {
	Millbrook = {
		DisplayName = "Elder Bram",
		Greeting = "Welcome to Millbrook, traveler. We could use a strong arm around here.",
		Position = Vector3.new(18, 0, 4), -- on the ground near spawn
		Quests = { "RatProblem", "BanditTrouble", "CaptainHunt" },
	},
	Whisperwood = {
		DisplayName = "Ranger Elda",
		Model = "Ranger",
		Greeting = "Keep your voice down. The forest has ears, and most of them are pointy.",
		Position = Vector3.new(48, 0, -445),
		Quests = { "WolfHunt", "GoblinRaid", "GoblinKingQuest" },
	},
}

Quests.List = {
	RatProblem = {
		Title = "Rat Problem",
		Description = "Rats are eating the village grain! Clear some out of the Rat Field.",
		Enemy = "Rat", -- key in Config/Enemies
		Count = 6,
		MinLevel = 1,
		XP = 270,
		Gold = 60,
	},
	BanditTrouble = {
		Title = "Bandit Trouble",
		Description = "Bandit Thugs have made camp east of the village. Show them Millbrook isn't easy pickings.",
		Enemy = "BanditThug",
		Count = 6,
		MinLevel = 10,
		XP = 990,
		Gold = 200,
	},
	CaptainHunt = {
		Title = "The Bandit Captain",
		Description = "Their leader hides in a clearing past the camp. Take him down.",
		Enemy = "BanditCaptain",
		Count = 1,
		MinLevel = 20,
		XP = 3000,
		Gold = 800,
	},
	WolfHunt = {
		Title = "Thin the Pack",
		Description = "Wolves have been stalking travelers near their den. Drive them off.",
		Enemy = "Wolf",
		Count = 8,
		MinLevel = 30,
		XP = 4800,
		Gold = 900,
	},
	GoblinRaid = {
		Title = "Goblin Raid",
		Description = "Goblins keep stealing our arrows. Raid their camp in the east woods.",
		Enemy = "Goblin",
		Count = 8,
		MinLevel = 55,
		XP = 8400,
		Gold = 1600,
	},
	GoblinKingQuest = {
		Title = "Crown of Sticks",
		Description = "The Goblin King sits on his throne in the south. End his reign.",
		Enemy = "GoblinKing",
		Count = 1,
		MinLevel = 70,
		XP = 12000,
		Gold = 3000,
	},
}

Quests.TalkDistance = 14 -- how close you must be to accept a quest

return Quests
