-- Server entry point. Starts every service in order.

local Services = script.Parent.Services

local order = {
	"AssetService",
	"DataService",
	"CharacterService",
	"LevelingService",
	"CombatService",
	"EnergyService",
	"LoadoutService",
	"GemService",
	"TrainingGround",
	"QuestService",
	"MerchantService",
	"GemSpawner",
	"EnemyService",
	"DevCommands",
}

for _, name in order do
	-- If one fails, warn and keep going so the rest still start.
	local ok, err = pcall(function()
		local service = require(Services[name]) :: any
		service.Start()
	end)
	if not ok then
		warn(("[Main] %s failed to start: %s"):format(name, tostring(err)))
	end
end
