-- Energy: spent by gem moves (and later dashes), refills over time.
-- Max energy = 100 + 5 per Vitality point. Copied onto the player as the
-- attributes Energy and MaxEnergy for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local DataService = require(script.Parent.DataService)

local TICK = 0.1

local EnergyService = {}

local energy: { [Player]: number } = {}

local function maxEnergy(player: Player): number
	local profile = DataService.Get(player)
	local vitality = if profile then profile.Data.Stats.Vitality else 0
	return Gems.Energy.Base + vitality * Gems.Energy.PerVitality
end

local function publish(player: Player)
	player:SetAttribute("MaxEnergy", maxEnergy(player))
	player:SetAttribute("Energy", math.floor((energy[player] or 0) * 10 + 0.5) / 10)
end

-- Takes energy if the player has enough. Returns whether it did.
function EnergyService.Spend(player: Player, amount: number): boolean
	local current = energy[player]
	if not current or current < amount then
		return false
	end
	energy[player] = current - amount
	publish(player)
	return true
end

function EnergyService.Refill(player: Player)
	energy[player] = maxEnergy(player)
	publish(player)
end

function EnergyService.Start()
	DataService.OnLoaded(function(player)
		EnergyService.Refill(player)
		player.CharacterAdded:Connect(function()
			EnergyService.Refill(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		energy[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for player, current in energy do
				local max = maxEnergy(player)
				if current < max then
					energy[player] = math.min(max, current + Gems.Energy.RegenPerSecond * TICK)
					publish(player)
				elseif player:GetAttribute("MaxEnergy") ~= max then
					publish(player)
				end
			end
		end
	end)
end

return EnergyService
