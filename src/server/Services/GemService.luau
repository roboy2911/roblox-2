-- Moves on Z / X / C for whichever build slot is selected (style, weapon
-- or gem), plus gems themselves (one at a time; eating a new one replaces it).
--
-- A move is cast if the player's level is high enough, it's off cooldown
-- and there's enough energy. The server decides what gets hit; every client
-- is told so it can draw the effects (Remotes.AbilityFx). The caster's
-- client moves the caster during dashes, since it controls its own character.
--
-- Player attributes: Gem (gem id or ""), CD_<Slot>_<Key> (server time when
-- that move is ready again, e.g. CD_Weapon_Z).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Damageable = require(script.Parent.Damageable)
local EnergyService = require(script.Parent.EnergyService)
local LoadoutService = require(script.Parent.LoadoutService)
local Loadout = require(ReplicatedStorage.Shared.Loadout)

local KEYS = { Z = true, X = true, C = true }
local COOLDOWN_GRACE = 0.1 -- allow a press to arrive a little early
local FIREBALL_HIT_RADIUS = 2.5 -- how close a fireball must pass to hit an enemy

local GemService = {}

local nextProjectileId = 0

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

local function validVector(v: any): boolean
	return typeof(v) == "Vector3" and v.Magnitude == v.Magnitude and v.Magnitude < 1e6 -- rejects NaN and junk
end

-- Every living target that can be hit.
local function targets(): { Model }
	local list = {}
	for _, model in CollectionService:GetTagged(Damageable.Tag) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) and Damageable.IsAlive(model) then
			table.insert(list, model)
		end
	end
	return list
end

-- The middle of a target's body (where it's hit).
local function center(model: Model): Vector3
	return model:GetPivot().Position + Vector3.new(0, model:GetAttribute("HitHeight") or 2, 0)
end

local function hitRadius(model: Model): number
	return model:GetAttribute("HitRadius") or 1.5
end

-- Stat that boosts the move being cast (set per cast; see onUseAbility).
local function damage(player: Player, target: Model, base: number, stun: number, heavy: boolean, stat: string)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local amount = Combat.CalculateDamage(base, profile.Data.Stats[stat] or 0, target:GetAttribute("Defense") or 0)
	local dealt, killed = Damageable.ApplyDamage(target, amount, player, { Heavy = heavy })
	if dealt > 0 then
		Damageable.Stun(target, stun)
		Remotes.HitEffect:FireAllClients(player, target, dealt, killed, heavy)
	end
end

-- Distance from a point to the line segment a-b.
local function distanceToSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local length = ab.Magnitude
	if length < 0.001 then
		return (point - a).Magnitude
	end
	local t = math.clamp((point - a):Dot(ab) / (length * length), 0, 1)
	return (point - (a + ab * t)).Magnitude
end

-- Moves -------------------------------------------------------------------

local function projectile(player: Player, root: BasePart, move, aim: any, stat: string)
	local look = flat(root.CFrame.LookVector).Unit
	local origin = root.Position + Vector3.new(0, 1.2, 0) + look * 2
	local direction = look
	if validVector(aim) and (aim - origin).Magnitude > 1 then
		direction = (aim - origin).Unit
	end

	nextProjectileId += 1
	local id = nextProjectileId
	Remotes.AbilityFx:FireAllClients("Fireball", player, id, origin, direction, move.Speed, move.Range, move.CastTime)

	task.delay(move.CastTime, function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore: { Instance } = {}
		for _, other in Players:GetPlayers() do
			if other.Character then
				table.insert(ignore, other.Character)
			end
		end
		params.FilterDescendantsInstances = ignore

		local position = origin
		local traveled = 0
		local exploded = false
		local function explode(at: Vector3)
			exploded = true
			Remotes.AbilityFx:FireAllClients("FireballHit", player, id, at)
			for _, target in targets() do
				if (center(target) - at).Magnitude <= move.BlastRadius + hitRadius(target) then
					damage(player, target, move.Damage, move.Stun, false, stat)
				end
			end
		end

		while not exploded do
			local dt = RunService.Heartbeat:Wait()
			local step = math.min(move.Speed * dt, move.Range - traveled)
			local nextPosition = position + direction * step

			-- Passed close to an enemy?
			for _, target in targets() do
				if distanceToSegment(center(target), position, nextPosition) <= FIREBALL_HIT_RADIUS + hitRadius(target) then
					explode(nextPosition)
					break
				end
			end
			if exploded then
				break
			end
			-- Hit the ground or a wall?
			local hit = workspace:Raycast(position, direction * step, params)
			if hit then
				explode(hit.Position)
				break
			end
			position = nextPosition
			traveled += step
			if traveled >= move.Range then
				explode(position)
			end
		end
	end)
end

-- Rush forward, hitting everything along the path actually taken.
local function dash(player: Player, root: BasePart, move, aim: any, stat: string)
	local direction = flat(root.CFrame.LookVector).Unit
	if validVector(aim) and flat(aim).Magnitude > 0.01 then
		direction = flat(aim).Unit
	end
	local start = root.Position
	Remotes.AbilityFx:FireAllClients("Dash", player, start, direction, move.Distance, move.DashTime, move.Fx, move.Animation)

	task.delay(move.DashTime + 0.05, function()
		if not root.Parent then
			return
		end
		local finish = root.Position
		if (finish - start).Magnitude > move.Distance * 1.5 then
			finish = start + direction * move.Distance -- moved suspiciously far; use the expected path
		end
		for _, target in targets() do
			local offset = flat(center(target) - start)
			local along = flat(finish - start)
			local closest = distanceToSegment(flat(center(target)), flat(start), flat(start) + along)
			if closest <= move.HitWidth + hitRadius(target) and offset.Magnitude <= along.Magnitude + move.HitWidth + 2 then
				damage(player, target, move.Damage, move.Stun, move.Heavy == true, stat)
			end
		end
	end)
end

-- Hits all around the caster, Hits times.
local function burst(player: Player, root: BasePart, move, _aim: any, stat: string)
	local hits = move.Hits or 1
	Remotes.AbilityFx:FireAllClients("Burst", player, root.Position, move.Radius, move.CastTime, move.Fx, move.Animation, hits, move.Interval or 0)
	for i = 1, hits do
		task.delay(move.CastTime + (i - 1) * (move.Interval or 0), function()
			if not root.Parent then
				return
			end
			local origin = root.Position
			for _, target in targets() do
				if flat(target:GetPivot().Position - origin).Magnitude <= move.Radius + hitRadius(target) then
					-- One big hit launches enemies; multi-hit spins don't.
					damage(player, target, move.Damage, move.Stun, hits == 1, stat)
				end
			end
		end)
	end
end

-- Hits in front of the caster, Hits times (punch flurries, slash combos, chops).
local function flurry(player: Player, root: BasePart, move, aim: any, stat: string)
	local hits = move.Hits or 1
	local look = flat(root.CFrame.LookVector).Unit
	if validVector(aim) and flat(aim).Magnitude > 0.01 then
		look = flat(aim).Unit
	end
	Remotes.AbilityFx:FireAllClients("Flurry", player, move.Animation, move.Fx, move.Delay, hits, move.Interval or 0)
	for i = 1, hits do
		task.delay(move.Delay + (i - 1) * (move.Interval or 0), function()
			if not root.Parent then
				return
			end
			for _, target in targets() do
				local offset = flat(target:GetPivot().Position - root.Position)
				local inReach = offset.Magnitude <= move.Range + hitRadius(target)
				if inReach and (offset.Magnitude < 0.5 or look:Dot(offset.Unit) >= move.Arc) then
					damage(player, target, move.Damage, move.Stun, move.Heavy == true and i == hits, stat)
				end
			end
		end)
	end
end

local KINDS = {
	Projectile = projectile,
	Dash = dash,
	Burst = burst,
	Flurry = flurry,
}

-- Using moves ---------------------------------------------------------------

local function onUseAbility(player: Player, key: any, aim: any)
	if type(key) ~= "string" or not KEYS[key] then
		return
	end
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	-- Moves come from the selected slot (style, weapon or gem).
	local state = Loadout.Of(player)
	local moves = Loadout.Moves(state)
	local move = moves and moves[key]
	if not move or profile.Data.Level < move.Level then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local cooldownName = ("CD_%s_%s"):format(state.Slot, key)
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute(cooldownName) or 0) - COOLDOWN_GRACE then
		return
	end
	if not EnergyService.Spend(player, move.Energy) then
		return
	end
	player:SetAttribute(cooldownName, now + move.Cooldown)

	local attack = Loadout.Attack(state)
	local stat = if state.Slot == "Gem" then "GemPower" else attack.Stat
	local cast = KINDS[move.Kind]
	if cast then
		cast(player, root, move, aim, stat)
	end
end

-- Gives a player a gem (replacing the one they had) and resets cooldowns.
function GemService.SetGem(player: Player, gemId: string)
	local profile = DataService.Get(player)
	if not profile or (gemId ~= "" and not Gems.List[gemId]) then
		return
	end
	profile.Data.Gem = gemId
	player:SetAttribute("Gem", gemId)
	for key in KEYS do
		player:SetAttribute("CD_Gem_" .. key, 0)
	end
	if gemId ~= "" then
		Remotes.AbilityFx:FireAllClients("GemEaten", player, gemId)
	end
	-- Switch to the gem slot when you get one; leave it if the gem is gone.
	LoadoutService.Select(player, if gemId ~= "" then "Gem" else "Style")
end

function GemService.Start()
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
	DataService.OnLoaded(function(player, profile)
		player:SetAttribute("Gem", profile.Data.Gem)
	end)
end

return GemService
