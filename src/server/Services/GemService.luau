-- Gems and their moves. A player holds one gem at a time (eating a new one
-- replaces it). Pressing Z / X / C casts that gem's moves, if the player's
-- level is high enough, the move is off cooldown and there's enough energy.
--
-- The server decides what gets hit; every client is told so it can draw
-- the effects (Remotes.AbilityFx). The caster's client moves the caster
-- during Flame Dash, since it controls its own character.
--
-- Player attributes: Gem (gem id or ""), CD_Z / CD_X / CD_C (server time
-- when each move is ready again).

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

local function damage(player: Player, target: Model, base: number, stun: number, heavy: boolean)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local amount = Combat.CalculateDamage(base, profile.Data.Stats.GemPower, target:GetAttribute("Defense") or 0)
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

local function fireball(player: Player, root: BasePart, move, aim: any)
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
					damage(player, target, move.Damage, move.Stun, false)
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

local function flameDash(player: Player, root: BasePart, move, aim: any)
	local direction = flat(root.CFrame.LookVector).Unit
	if validVector(aim) and flat(aim).Magnitude > 0.01 then
		direction = flat(aim).Unit
	end
	local start = root.Position
	Remotes.AbilityFx:FireAllClients("FlameDash", player, start, direction, move.Distance, move.DashTime)

	-- Burn everything along the path the player actually took.
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
				damage(player, target, move.Damage, move.Stun, false)
			end
		end
	end)
end

local function fireRing(player: Player, root: BasePart, move)
	Remotes.AbilityFx:FireAllClients("FireRing", player, root.Position, move.Radius, move.CastTime)
	task.delay(move.CastTime, function()
		if not root.Parent then
			return
		end
		local origin = root.Position
		for _, target in targets() do
			if flat(target:GetPivot().Position - origin).Magnitude <= move.Radius + hitRadius(target) then
				damage(player, target, move.Damage, move.Stun, true) -- heavy: launches enemies
			end
		end
	end)
end

local MOVES = {
	Fireball = fireball,
	["Flame Dash"] = flameDash,
	["Fire Ring"] = fireRing,
}

-- Using moves ---------------------------------------------------------------

local function onUseAbility(player: Player, key: any, aim: any)
	if type(key) ~= "string" or not KEYS[key] then
		return
	end
	local profile = DataService.Get(player)
	local gem = profile and Gems.List[profile.Data.Gem]
	local move = gem and gem.Moves[key]
	if not profile or not move or profile.Data.Level < move.Level then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end

	local now = workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("CD_" .. key) or 0
	if now < readyAt - COOLDOWN_GRACE then
		return
	end
	if not EnergyService.Spend(player, move.Energy) then
		return
	end
	player:SetAttribute("CD_" .. key, now + move.Cooldown)

	local cast = MOVES[move.Name]
	if cast then
		cast(player, root, move, aim)
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
		player:SetAttribute("CD_" .. key, 0)
	end
	if gemId ~= "" then
		Remotes.AbilityFx:FireAllClients("GemEaten", player, gemId)
	end
end

function GemService.Start()
	Remotes.UseAbility.OnServerEvent:Connect(onUseAbility)
	DataService.OnLoaded(function(player, profile)
		player:SetAttribute("Gem", profile.Data.Gem)
	end)
end

return GemService
