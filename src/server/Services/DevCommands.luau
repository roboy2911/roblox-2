-- Chat commands for testing. Only work in Roblox Studio, never in the live game.
--   /xp 500       give yourself XP
--   /gold 1000    give yourself gold
--   /resetdata    start over at level 1
--   /level 10     jump to a level
--   /gem          eat the Ember Gem (/gem none removes it)
--   /spawngem     put a gem under a tree right now
--   /weapon axe   get a weapon (sword or axe)
--   /spawnboss    bring the Bandit Captain back now

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local LevelingService = require(script.Parent.LevelingService)
local CharacterService = require(script.Parent.CharacterService)
local QuestService = require(script.Parent.QuestService)
local GemService = require(script.Parent.GemService)
local GemSpawner = require(script.Parent.GemSpawner)
local LoadoutService = require(script.Parent.LoadoutService)
local EnemyService = require(script.Parent.EnemyService)
local StatsService = require(script.Parent.StatsService)

local DevCommands = {}

local commands = {
	xp = function(player: Player, amount: number?)
		LevelingService.AddXP(player, amount or 100)
	end,
	gold = function(player: Player, amount: number?)
		LevelingService.AddGold(player, amount or 100)
	end,
	level = function(player: Player, level: number?)
		local profile = DataService.Get(player)
		if profile and level then
			-- Add exactly the XP needed to reach that level.
			local data = profile.Data
			local needed = -data.XP
			for l = data.Level, math.min(level, 300) - 1 do
				needed += Leveling.XPToNext(l)
			end
			LevelingService.AddXP(player, needed)
		end
	end,
	gem = function(player: Player, _: number?, word: string?)
		if word == "none" then
			GemService.SetGem(player, "")
		else
			GemService.SetGem(player, "Ember")
		end
	end,
	weapon = function(player: Player, _: number?, word: string?)
		LoadoutService.GiveWeapon(player, if word == "axe" then "BattleAxe" else "IronSword")
	end,
	spawnboss = function(player: Player)
		if EnemyService.SpawnBosses() == 0 then
			Remotes.Notify:FireClient(player, "The boss is already alive")
		end
	end,
	spawngem = function(player: Player)
		if not GemSpawner.SpawnGem() then
			Remotes.Notify:FireClient(player, "A gem is already out there")
		end
	end,
	resetdata = function(player: Player)
		DataService.Reset(player)
		LevelingService.Sync(player)
		QuestService.Sync(player)
		StatsService.Sync(player)
		CharacterService.Refresh(player, true)
		Remotes.Notify:FireClient(player, "Data reset to level 1")
	end,
}

local function onChatted(player: Player, message: string)
	local name, arg = string.match(message, "^/(%a+)%s*(%S*)")
	local command = name and commands[string.lower(name)]
	if command then
		command(player, tonumber(arg), string.lower(arg))
	end
end

function DevCommands.Start()
	if not RunService:IsStudio() then
		return
	end

	-- New chat system: register real chat commands.
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		for name in commands do
			local command = Instance.new("TextChatCommand")
			command.Name = "Dev_" .. name
			command.PrimaryAlias = "/" .. name
			command.Triggered:Connect(function(source: TextSource, message: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					onChatted(player, message)
				end
			end)
			command.Parent = TextChatService
		end
		return
	end

	-- Legacy chat.
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			onChatted(player, message)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end
end

return DevCommands
