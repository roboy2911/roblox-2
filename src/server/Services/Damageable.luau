-- Anything players can hit (training dummies now, enemies and bosses later).
-- Health lives in attributes on the model so clients can draw HP bars:
--   Health, MaxHealth, DisplayName, Level, Defense, Dead, StunnedUntil,
--   BarHeight, HitHeight

local CollectionService = game:GetService("CollectionService")

local Damageable = {}

Damageable.Tag = "Damageable"

type DiedCallback = (model: Model, contributors: { [Player]: number }) -> ()

local contributors: { [Model]: { [Player]: number } } = setmetatable({}, { __mode = "k" }) :: any
local diedCallbacks: { [Model]: { DiedCallback } } = setmetatable({}, { __mode = "k" }) :: any

export type Options = {
	DisplayName: string,
	MaxHealth: number,
	Level: number?,
	Defense: number?,
	BarHeight: number?, -- studs above the model's pivot to draw the HP bar
	HitHeight: number?, -- studs above the pivot where hit effects appear
}

function Damageable.Setup(model: Model, options: Options)
	model:SetAttribute("DisplayName", options.DisplayName)
	model:SetAttribute("MaxHealth", options.MaxHealth)
	model:SetAttribute("Health", options.MaxHealth)
	model:SetAttribute("Level", options.Level or 1)
	model:SetAttribute("Defense", options.Defense or 0)
	model:SetAttribute("BarHeight", options.BarHeight or 6)
	model:SetAttribute("HitHeight", options.HitHeight or (options.BarHeight or 6) * 0.5)
	model:SetAttribute("Dead", false)
	model:SetAttribute("StunnedUntil", 0)
	contributors[model] = {}
	CollectionService:AddTag(model, Damageable.Tag)
end

function Damageable.IsAlive(model: Model): boolean
	return CollectionService:HasTag(model, Damageable.Tag) and not model:GetAttribute("Dead")
end

function Damageable.OnDied(model: Model, callback: DiedCallback)
	diedCallbacks[model] = diedCallbacks[model] or {}
	table.insert(diedCallbacks[model], callback)
end

function Damageable.Stun(model: Model, seconds: number)
	local untilTime = workspace:GetServerTimeNow() + seconds
	model:SetAttribute("StunnedUntil", math.max(untilTime, model:GetAttribute("StunnedUntil") or 0))
end

-- Deals damage. Returns the damage actually dealt and whether it killed.
function Damageable.ApplyDamage(model: Model, amount: number, attacker: Player?): (number, boolean)
	if not Damageable.IsAlive(model) then
		return 0, false
	end
	local health = model:GetAttribute("Health") :: number
	local dealt = math.min(health, math.max(0, amount))
	health -= dealt
	model:SetAttribute("Health", health)

	if attacker then
		local list = contributors[model]
		if list then
			list[attacker] = (list[attacker] or 0) + dealt
		end
	end

	if health <= 0 then
		model:SetAttribute("Dead", true)
		local list = contributors[model] or {}
		contributors[model] = {}
		for _, callback in diedCallbacks[model] or {} do
			task.spawn(callback, model, list)
		end
		return dealt, true
	end
	return dealt, false
end

-- Brings a dead target back to full health.
function Damageable.Reset(model: Model)
	model:SetAttribute("Health", model:GetAttribute("MaxHealth"))
	model:SetAttribute("Dead", false)
	model:SetAttribute("StunnedUntil", 0)
	contributors[model] = {}
end

return Damageable
