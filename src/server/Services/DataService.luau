-- Loads and saves each player's data with DataStoreService.
-- Saves on leave, every 2 minutes, and when the server shuts down.
-- If loading fails, the player can still play but nothing is saved, so a
-- bad load never overwrites a good save.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local RETRIES = 3

export type Profile = {
	Data: typeof(Leveling.DefaultData),
	CanSave: boolean,
}

local DataService = {}

local store: DataStore? = nil
local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}

local function deepCopy<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value :: any do
		copy[k] = deepCopy(v)
	end
	return copy :: any
end

-- Fills in any fields missing from an old save.
local function reconcile(data: any, template: any)
	for key, default in template do
		if data[key] == nil then
			data[key] = deepCopy(default)
		elseif type(default) == "table" and type(data[key]) == "table" then
			reconcile(data[key], default)
		end
	end
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function withRetries<T>(label: string, fn: () -> T): (boolean, T | string)
	local lastErr
	for attempt = 1, RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(("[DataService] %s failed (try %d/%d): %s"):format(label, attempt, RETRIES, tostring(result)))
		task.wait(attempt)
	end
	return false, lastErr
end

local function load(player: Player)
	local data = deepCopy(Leveling.DefaultData)
	local canSave = false

	if store then
		local ok, result = withRetries("Load " .. player.Name, function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
		if ok then
			if type(result) == "table" then
				data = result :: any
				reconcile(data, Leveling.DefaultData)
			end
			canSave = true
		end
	end

	if not player:IsDescendantOf(Players) then
		return -- left while loading
	end

	local profile: Profile = { Data = data, CanSave = canSave }
	profiles[player] = profile

	if not canSave then
		warn("[DataService] Playing without saving for " .. player.Name)
	end

	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
end

local function save(player: Player, profile: Profile)
	if not profile.CanSave or not store then
		return
	end
	withRetries("Save " .. player.Name, function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)
end

function DataService.Get(player: Player): Profile?
	return profiles[player]
end

-- Runs callback for every player once their data is loaded (including
-- players already loaded when this is called).
function DataService.OnLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, profile in profiles do
		task.spawn(callback, player, profile)
	end
end

-- Sets a player's data back to a fresh start (used by dev commands).
function DataService.Reset(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data = deepCopy(Leveling.DefaultData)
	end
end

function DataService.Start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable, progress will not save: " .. tostring(result))
		if RunService:IsStudio() then
			warn("[DataService] In Studio: publish the place, then Game Settings > Security > Enable Studio Access to API Services.")
		end
	end

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			save(player, profile)
			profiles[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				task.spawn(save, player, profile)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			pending += 1
			task.spawn(function()
				save(player, profile)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait()
		end
	end)
end

return DataService
