-- Client entry point. Starts every controller.

local Controllers = script.Parent.Controllers

for _, name in { "HUD", "CombatController", "HealthBars" } do
	local controller = require(Controllers[name]) :: any
	controller.Start()
end
