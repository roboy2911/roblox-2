-- Spending stat points and resetting stats.
-- Player attributes Stat_<Name> hold each stat for the menu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local LevelingService = require(script.Parent.LevelingService)

local StatsService = {}

local function sync(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, name in Leveling.StatNames do
		player:SetAttribute("Stat_" .. name, profile.Data.Stats[name])
	end
	LevelingService.Sync(player) -- stat points and gold
end

local function onAction(player: Player, action: any, stat: any, amount: any)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local data = profile.Data
	if action == "Spend" and type(stat) == "string" and data.Stats[stat] ~= nil and type(amount) == "number" then
		if data.StatPoints <= 0 then
			return
		end
		local points = math.clamp(math.floor(amount), 1, data.StatPoints)
		data.Stats[stat] += points
		data.StatPoints -= points
	elseif action == "Reset" then
		local cost = Leveling.ResetCost(data.Level)
		local spent = 0
		for _, name in Leveling.StatNames do
			spent += data.Stats[name]
		end
		if spent == 0 then
			return
		elseif data.Gold < cost then
			Remotes.Notify:FireClient(player, "Not enough gold")
			return
		end
		data.Gold -= cost
		for _, name in Leveling.StatNames do
			data.Stats[name] = 0
		end
		data.StatPoints += spent
		Remotes.Notify:FireClient(player, "Stats reset")
	else
		return
	end
	sync(player)
	CharacterService.Refresh(player) -- Vitality changes max HP
end

StatsService.Sync = sync

function StatsService.Start()
	DataService.OnLoaded(function(player)
		sync(player)
	end)
	Remotes.StatAction.OnServerEvent:Connect(onAction)
end

return StatsService
