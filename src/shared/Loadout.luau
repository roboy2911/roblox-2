-- The three build slots and what each one does. Used by both the server
-- (to check and resolve attacks) and clients (to animate and show the bar).
--   Key 1: Style   (your combat style, e.g. Brawler)
--   Key 2: Weapon  (your equipped weapon, if you have one)
--   Key 3: Gem     (your gem: fire punches on click, gem moves on Z/X/C)
--
-- The current state lives in player attributes: Slot, Style, Weapon, Gem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Gems = require(ReplicatedStorage.Shared.Config.Gems)

local Loadout = {}

Loadout.Slots = { "Style", "Weapon", "Gem" } -- in key order 1, 2, 3

export type State = { Slot: string, Style: string, Weapon: string, Gem: string }

function Loadout.Of(player: Player): State
	return {
		Slot = player:GetAttribute("Slot") or "Style",
		Style = player:GetAttribute("Style") or Combat.DefaultStyle,
		Weapon = player:GetAttribute("Weapon") or "",
		Gem = player:GetAttribute("Gem") or "",
	}
end

-- The click combo for the selected slot, and an id clients can look it up by.
function Loadout.Attack(state: State): (any, string)
	if state.Slot == "Weapon" and Combat.Weapons[state.Weapon] then
		return Combat.Weapons[state.Weapon], "Weapon:" .. state.Weapon
	elseif state.Slot == "Gem" and Gems.List[state.Gem] then
		return Combat.GemPunches, "Gem"
	end
	local style = Combat.Styles[state.Style] and state.Style or Combat.DefaultStyle
	return Combat.Styles[style], "Style:" .. style
end

-- Looks up a click combo by the id from Loadout.Attack.
function Loadout.AttackById(id: string): any
	if id == "Gem" then
		return Combat.GemPunches
	end
	local kind, name = string.match(id, "^(%a+):(%w+)$")
	if kind == "Weapon" then
		return Combat.Weapons[name]
	elseif kind == "Style" then
		return Combat.Styles[name]
	end
	return nil
end

-- The Z/X/C moves for the selected slot (nil if the slot is empty).
function Loadout.Moves(state: State): { [string]: any }?
	if state.Slot == "Gem" then
		local gem = Gems.List[state.Gem]
		return gem and gem.Moves
	elseif state.Slot == "Weapon" then
		local weapon = Combat.Weapons[state.Weapon]
		return weapon and weapon.Moves
	end
	local style = Combat.Styles[state.Style] or Combat.Styles[Combat.DefaultStyle]
	return style.Moves
end

-- What to call a slot on the hotbar ("" if empty).
function Loadout.SlotLabel(state: State, slot: string): string
	if slot == "Weapon" then
		local weapon = Combat.Weapons[state.Weapon]
		return weapon and weapon.DisplayName or ""
	elseif slot == "Gem" then
		local gem = Gems.List[state.Gem]
		return gem and gem.DisplayName or ""
	end
	local style = Combat.Styles[state.Style] or Combat.Styles[Combat.DefaultStyle]
	return style.DisplayName
end

return Loadout
