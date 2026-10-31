-- Quest givers and their quests. Rewards follow the design doc: about
-- 1.5x the XP of the kills, plus gold.

local Quests = {}

Quests.Givers = {
	Millbrook = {
		DisplayName = "Elder Bram",
		Greeting = "Welcome to Millbrook, traveler. We could use a strong arm around here.",
		Position = Vector3.new(18, 0, 4), -- on the ground near spawn
		Quests = { "RatProblem", "BanditTrouble" },
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
}

Quests.TalkDistance = 14 -- how close you must be to accept a quest

return Quests
