-- Chat commands for testing. Only work in Roblox Studio, never in the live game.
--   /xp 500       give yourself XP
--   /gold 1000    give yourself gold
--   /resetdata    start over at level 1

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local LevelingService = require(script.Parent.LevelingService)
local CharacterService = require(script.Parent.CharacterService)

local DevCommands = {}

local commands = {
	xp = function(player: Player, amount: number?)
		LevelingService.AddXP(player, amount or 100)
	end,
	gold = function(player: Player, amount: number?)
		LevelingService.AddGold(player, amount or 100)
	end,
	resetdata = function(player: Player)
		DataService.Reset(player)
		LevelingService.Sync(player)
		CharacterService.Refresh(player, true)
		Remotes.Notify:FireClient(player, "Data reset to level 1")
	end,
}

local function onChatted(player: Player, message: string)
	local name, arg = string.match(message, "^/(%a+)%s*(%S*)")
	local command = name and commands[string.lower(name)]
	if command then
		command(player, tonumber(arg))
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
