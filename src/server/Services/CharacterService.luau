-- Sets each character's max HP from the player's Vitality stat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local function apply(player: Player, healFull: boolean)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid or humanoid.Health <= 0 then
		return
	end
	local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
	humanoid.MaxHealth = Leveling.MaxHealth(profile.Data.Stats.Vitality)
	humanoid.Health = if healFull then humanoid.MaxHealth else humanoid.MaxHealth * ratio
end

-- Call after stats change. healFull restores HP to max (used on level up).
function CharacterService.Refresh(player: Player, healFull: boolean?)
	apply(player, healFull == true)
end

function CharacterService.Start()
	DataService.OnLoaded(function(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			apply(player, true)
		end)
		if player.Character then
			apply(player, true)
		end
	end)
end

return CharacterService
