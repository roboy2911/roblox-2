-- Client entry point. Starts every controller.

local Controllers = script.Parent.Controllers

for _, name in { "HUD", "CombatController", "HealthBars", "EnemyAnimator", "Feedback", "QuestUI", "NpcController", "AbilityController", "ShopUI", "WorldEffects", "BossBar", "StatsUI", "BoatController" } do
	-- If one fails, warn and keep going so the rest still start.
	local ok, err = pcall(function()
		local controller = require(Controllers[name]) :: any
		controller.Start()
	end)
	if not ok then
		warn(("[Main] %s failed to start: %s"):format(name, tostring(err)))
	end
end
