-- XP, levels and stat points. Copies the numbers onto the player as
-- attributes (for the HUD) and into leaderstats (for the player list).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local CharacterService = require(script.Parent.CharacterService)

local LevelingService = {}

local function ensureLeaderstats(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
		for _, name in { "Level", "Gold" } do
			local value = Instance.new("IntValue")
			value.Name = name
			value.Parent = leaderstats
		end
	end
	return leaderstats
end

-- Pushes saved data to attributes and leaderstats so clients can see it.
function LevelingService.Sync(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local data = profile.Data
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPToNext", if data.Level >= Leveling.MaxLevel then 0 else Leveling.XPToNext(data.Level))
	player:SetAttribute("Gold", data.Gold)
	player:SetAttribute("StatPoints", data.StatPoints)
	player:SetAttribute("Saving", profile.CanSave)
	player:SetAttribute("DataLoaded", true)

	local leaderstats = ensureLeaderstats(player)
	leaderstats.Level.Value = data.Level
	leaderstats.Gold.Value = data.Gold
end

function LevelingService.AddXP(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	local data = profile.Data
	if data.Level >= Leveling.MaxLevel then
		return
	end

	data.XP += math.floor(amount)
	local levelsGained = 0
	while data.Level < Leveling.MaxLevel and data.XP >= Leveling.XPToNext(data.Level) do
		data.XP -= Leveling.XPToNext(data.Level)
		data.Level += 1
		data.StatPoints += Leveling.StatPointsPerLevel
		levelsGained += 1
	end
	if data.Level >= Leveling.MaxLevel then
		data.XP = 0
	end

	LevelingService.Sync(player)
	if levelsGained > 0 then
		CharacterService.Refresh(player, true)
		Remotes.LevelUp:FireClient(player, data.Level, levelsGained * Leveling.StatPointsPerLevel)
	end
end

function LevelingService.AddGold(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Data.Gold = math.max(0, profile.Data.Gold + math.floor(amount))
	LevelingService.Sync(player)
end

function LevelingService.Start()
	DataService.OnLoaded(function(player)
		LevelingService.Sync(player)
	end)
end

return LevelingService
