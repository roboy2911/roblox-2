-- Combat numbers from the design doc. Tune here, not in the services.

local Combat = {}

-- Combat styles. Each click advances the combo; the last hit has a longer
-- cooldown so combos have a rhythm.
Combat.Styles = {
	Brawler = {
		DisplayName = "Brawler",
		Stat = "Strength", -- stat that boosts this style's damage
		-- HitDelay: seconds from click to the fist landing (matches the animation).
		-- Lunge: how far forward the player steps into the punch.
		Combo = {
			{ Damage = 12, Animation = "JabRight", HitDelay = 0.1, LungeSpeed = 22, LungeTime = 0.08 },
			{ Damage = 12, Animation = "JabLeft", HitDelay = 0.1, LungeSpeed = 22, LungeTime = 0.08 },
			{ Damage = 18, Animation = "UppercutRight", HitDelay = 0.2, LungeSpeed = 42, LungeTime = 0.14, Heavy = true },
		},
		Range = 6, -- studs in front of the player
		AimAssistRange = 12, -- clicking turns you toward a target this close
		HitArc = 0.3, -- dot product with look direction; 0.3 is about a 145 degree cone
		SwingCooldown = 0.35,
		ComboEndCooldown = 0.8,
		ComboResetTime = 1.2, -- combo starts over if you wait this long
		Stun = 0.3, -- combo hits stun for 0.3 seconds
	},
}

Combat.DefaultStyle = "Brawler"

-- Damage = base x (1 + 1% per stat point) x (1 - defense reduction).
-- Defense: -0.5% damage taken per point, capped at 50%.
function Combat.CalculateDamage(base: number, statPoints: number, defensePoints: number): number
	local reduction = math.min(0.5, defensePoints * 0.005)
	return math.floor(base * (1 + statPoints * 0.01) * (1 - reduction) + 0.5)
end

return Combat
