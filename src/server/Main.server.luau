-- Server entry point. Starts every service in order.

local Services = script.Parent.Services

local order = {
	"DataService",
	"CharacterService",
	"LevelingService",
	"CombatService",
	"TrainingGround",
	"DevCommands",
}

for _, name in order do
	local service = require(Services[name]) :: any
	service.Start()
end
