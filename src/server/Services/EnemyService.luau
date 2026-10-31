-- Spawns enemies in their spawn areas and runs their behavior:
--   wander around the area -> notice a nearby player -> chase -> attack
--   -> die, give XP and gold (and quest progress) -> respawn 15 seconds later
-- Enemies that get dragged too far from home walk back and heal.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Damageable = require(script.Parent.Damageable)
local EnemyRig = require(script.Parent.EnemyRig)
local LevelingService = require(script.Parent.LevelingService)
local Props = require(script.Parent.Props)
local QuestService = require(script.Parent.QuestService)
local GemSpawner = require(script.Parent.GemSpawner)

local ENEMY_TAG = "Enemy"
local THINK_INTERVAL = 0.1
local REWARD_SHARE = 0.1 -- players who dealt at least 10% of max HP get the reward
local ATTACK_RECOVERY = 0.3 -- stands still this long after attacking

type Area = typeof(Enemies.SpawnAreas[1])
type Enemy = {
	Model: Model,
	Config: any,
	Area: Area,
	Humanoid: Humanoid,
	Root: BasePart,
	Target: Player?,
	Returning: boolean,
	BusyUntil: number,
	NextAttack: number,
	NextWander: number,
	AttackToken: number,
	PatternIndex: number,
}

local EnemyService = {}

local enemiesFolder: Folder
local enemies: { [Model]: Enemy } = {}
local bosses: { [any]: Model } = {} -- living boss per spawn area
local rng = Random.new()

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

local function groundY(position: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { enemiesFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(Vector3.new(position.X, position.Y + 200, position.Z), Vector3.new(0, -400, 0), params)
	return if result then result.Position.Y else position.Y
end

local function randomPointIn(area: Area): Vector3
	local angle = rng:NextNumber(0, math.pi * 2)
	local distance = math.sqrt(rng:NextNumber()) * area.Radius
	local point = area.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
	return Vector3.new(point.X, groundY(point), point.Z)
end

local function livingRoot(player: Player?): BasePart?
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	return nil
end

local function cancelAttack(enemy: Enemy)
	enemy.AttackToken += 1
	enemy.BusyUntil = 0
	enemy.Model:SetAttribute("AttackStart", 0)
end

-- Knocks the enemy away from the attacker. Heavy hits launch it.
local function knockback(enemy: Enemy, attacker: Player?, heavy: boolean)
	local attackerRoot = livingRoot(attacker)
	if not attackerRoot then
		return
	end
	local direction = flat(enemy.Root.Position - attackerRoot.Position)
	direction = if direction.Magnitude > 0.01 then direction.Unit else attackerRoot.CFrame.LookVector
	local scale = enemy.Config.Knockback or 1
	enemy.Root.AssemblyLinearVelocity = (direction * (if heavy then 34 else 12) + Vector3.new(0, if heavy then 32 else 6, 0)) * scale
end

-- Rare drops (e.g. a gem from a boss) land on the ground where it died.
local function rollDrops(enemy: Enemy)
	for _, drop in enemy.Config.Drops or {} do
		if drop.Gem and rng:NextNumber() < drop.Chance then
			local spot = enemy.Root.Position
			GemSpawner.SpawnPickup(drop.Gem, spot, 120)
			for _, player in Players:GetPlayers() do
				Remotes.Notify:FireClient(player, ("The %s dropped a gem!"):format(enemy.Config.DisplayName))
			end
		end
	end
end

local function giveRewards(enemy: Enemy, contributors: { [Player]: number })
	local maxHealth = enemy.Model:GetAttribute("MaxHealth") or 1
	local position = enemy.Root.Position
	for player, damage in contributors do
		if player.Parent and damage >= maxHealth * REWARD_SHARE then
			local xp = enemy.Config.XP
			local gold = rng:NextInteger(enemy.Config.Gold[1], enemy.Config.Gold[2])
			LevelingService.AddXP(player, xp)
			LevelingService.AddGold(player, gold)
			Remotes.Reward:FireClient(player, position, xp, gold)
			QuestService.OnEnemyKilled(player, enemy.Model:GetAttribute("EnemyType"))
		end
	end
end

-- Rats flip onto their backs, bandits fall backwards; then they fade away.
local function playDeath(model: Model, root: BasePart)
	root.Anchored = true
	local start = model:GetPivot()
	local biped = model:GetAttribute("Rig") == "Biped"
	local hipHeight = (model:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight
	local roll = Instance.new("NumberValue")
	roll.Changed:Connect(function(value)
		if not model.Parent then
			return
		end
		local t = value / 180
		if biped then
			-- Tip back around the feet until lying flat.
			local feet = start * CFrame.new(0, -(hipHeight + root.Size.Y / 2), 0)
			model:PivotTo(feet * CFrame.Angles(math.rad(90 * t), 0, 0) * feet:ToObjectSpace(start) * CFrame.new(0, -0.3 * t, 0))
		else
			model:PivotTo(start * CFrame.new(0, t * 0.4, 0) * CFrame.Angles(0, 0, math.rad(value)))
		end
	end)
	TweenService:Create(roll, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = 180 }):Play()
	task.delay(0.6, function()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part ~= root then
				TweenService:Create(part, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			end
		end
	end)
	Debris:AddItem(roll, 1.3)
	Debris:AddItem(model, 1.3)
end

local spawnEnemy: (area: Area) -> ()

local function onDied(enemy: Enemy, contributors: { [Player]: number })
	enemies[enemy.Model] = nil
	if bosses[enemy.Area] == enemy.Model then
		bosses[enemy.Area] = nil
		for _, player in Players:GetPlayers() do
			Remotes.Notify:FireClient(player, enemy.Config.DisplayName .. " has been defeated!")
		end
	end
	cancelAttack(enemy)
	giveRewards(enemy, contributors)
	rollDrops(enemy)
	playDeath(enemy.Model, enemy.Root)
	task.delay(enemy.Config.RespawnTime, function()
		if not (enemy.Config.Boss and bosses[enemy.Area]) then -- /spawnboss may have brought it back already
			spawnEnemy(enemy.Area)
		end
	end)
end

function spawnEnemy(area: Area)
	local config = Enemies.Types[area.Enemy]
	local model = EnemyRig.Get(area.Enemy, config):Clone()
	local root = model.PrimaryPart :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	local point = randomPointIn(area)
	local height = humanoid.HipHeight + root.Size.Y / 2 + 0.2
	model:PivotTo(CFrame.new(point + Vector3.new(0, height, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = enemiesFolder
	root:SetNetworkOwner(nil) -- server moves enemies, so they don't stutter

	Damageable.Setup(model, {
		DisplayName = config.DisplayName,
		MaxHealth = config.MaxHealth,
		Level = config.Level,
		Defense = config.Defense,
		BarHeight = model:GetAttribute("TemplateBarHeight"),
		HitHeight = model:GetAttribute("TemplateHitHeight"),
	})
	-- Extra reach for player punches: long enemies (rats) need more than tall ones.
	model:SetAttribute("HitRadius", if config.Length then config.Length * 0.35 else 1.5)
	model:SetAttribute("AttackStart", 0)
	model:SetAttribute("AttackWindup", config.AttackWindup)
	CollectionService:AddTag(model, ENEMY_TAG)

	local enemy: Enemy = {
		Model = model,
		Config = config,
		Area = area,
		Humanoid = humanoid,
		Root = root,
		Target = nil,
		Returning = false,
		BusyUntil = 0,
		NextAttack = 0,
		NextWander = os.clock() + rng:NextNumber(0, 3),
		AttackToken = 0,
		PatternIndex = 1,
	}
	enemies[model] = enemy
	if config.Boss then
		model:SetAttribute("Boss", true)
		model:SetAttribute("StunResist", true)
		bosses[area] = model
	end

	Damageable.OnDamaged(model, function(_, _, attacker, info)
		if not config.Boss then
			cancelAttack(enemy) -- bosses finish what they start
		end
		knockback(enemy, attacker, info.Heavy == true)
		if attacker and not enemy.Returning then
			enemy.Target = attacker
		end
	end)
	Damageable.OnDied(model, function(_, contributors)
		onDied(enemy, contributors)
	end)
end

local function strike(enemy: Enemy, target: Player, token: number)
	if token ~= enemy.AttackToken or not enemies[enemy.Model] then
		return
	end
	enemy.Model:SetAttribute("AttackStart", 0)
	local targetRoot = livingRoot(target)
	if not targetRoot then
		return
	end
	local offset = flat(targetRoot.Position - enemy.Root.Position)
	local facing = flat(enemy.Root.CFrame.LookVector)
	-- The player can dodge by moving out of range or behind the enemy.
	if offset.Magnitude > enemy.Config.AttackRange + 1.5 or (offset.Magnitude > 1 and facing:Dot(offset.Unit) < 0.2) then
		return
	end
	local humanoid = (targetRoot.Parent :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local profile = DataService.Get(target)
	local defense = if profile then profile.Data.Stats.Defense else 0
	local damage = Combat.CalculateDamage(enemy.Config.AttackDamage, 0, defense)
	humanoid:TakeDamage(damage) -- respects spawn ForceFields
	enemy.Root.AssemblyLinearVelocity += facing * 16
	Remotes.PlayerHit:FireClient(target, enemy.Model, damage)
end

local function startAttack(enemy: Enemy, target: Player, targetRoot: BasePart)
	local now = os.clock()
	local config = enemy.Config
	enemy.NextAttack = now + config.AttackCooldown
	enemy.BusyUntil = now + config.AttackWindup + ATTACK_RECOVERY
	enemy.Humanoid:MoveTo(enemy.Root.Position)

	local position = enemy.Root.Position
	enemy.Root.CFrame = CFrame.lookAt(position, Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z))

	enemy.AttackToken += 1
	local token = enemy.AttackToken
	enemy.Model:SetAttribute("AttackStart", workspace:GetServerTimeNow()) -- clients play the wind-up and attack
	task.delay(config.AttackWindup, strike, enemy, target, token)
end

-- Boss attacks ------------------------------------------------------------------

local function hurtPlayer(enemy: Enemy, player: Player, base: number, push: Vector3?)
	local root = livingRoot(player)
	if not root then
		return
	end
	local humanoid = (root.Parent :: Model):FindFirstChildOfClass("Humanoid") :: Humanoid
	local profile = DataService.Get(player)
	local defense = if profile then profile.Data.Stats.Defense else 0
	local damage = Combat.CalculateDamage(base, 0, defense)
	humanoid:TakeDamage(damage)
	-- The player's own client moves their character, so it applies the push.
	Remotes.PlayerHit:FireClient(player, enemy.Model, damage, push)
end

-- A red area on the ground that shows where an attack will land.
local function warningCircle(center: Vector3, radius: number, seconds: number): BasePart
	local part = Instance.new("Part")
	part.Name = "AttackWarning"
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.15, radius * 2, radius * 2)
	part.CFrame = CFrame.new(center.X, groundY(center) + 0.12, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = Color3.fromRGB(220, 40, 30)
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0.75
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 0.35 }):Play()
	Debris:AddItem(part, seconds + 0.05)
	return part
end

local function playersNear(center: Vector3, radius: number): { [Player]: BasePart }
	local found = {}
	for _, player in Players:GetPlayers() do
		local root = livingRoot(player)
		if root and flat(root.Position - center).Magnitude <= radius then
			found[player] = root
		end
	end
	return found
end

local function startCleave(enemy: Enemy, attack, targetRoot: BasePart, token: number)
	local root = enemy.Root
	local position = root.Position
	root.CFrame = CFrame.lookAt(position, Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z))
	local look = flat(root.CFrame.LookVector).Unit
	warningCircle(position + look * attack.Radius * 0.5, attack.Radius * 0.6, attack.Windup)
	task.delay(attack.Windup, function()
		if token ~= enemy.AttackToken or not enemies[enemy.Model] then
			return
		end
		for player, playerRoot in playersNear(root.Position, attack.Radius) do
			local offset = flat(playerRoot.Position - root.Position)
			if offset.Magnitude < 1 or look:Dot(offset.Unit) >= attack.Arc then
				hurtPlayer(enemy, player, attack.Damage, offset.Unit * 30 + Vector3.new(0, 18, 0))
			end
		end
	end)
end

local function startSlam(enemy: Enemy, attack, targetRoot: BasePart, token: number)
	local root = enemy.Root
	local spot = flat(targetRoot.Position) + Vector3.new(0, groundY(targetRoot.Position), 0)
	local start = root.Position
	root.CFrame = CFrame.lookAt(start, Vector3.new(spot.X, start.Y, spot.Z))
	local total = attack.Windup + attack.LeapTime
	warningCircle(spot, attack.Radius, total)

	task.delay(attack.Windup, function()
		if token ~= enemy.AttackToken or not enemies[enemy.Model] then
			return
		end
		-- Leap in an arc, landing on the marked spot.
		local height = enemy.Humanoid.HipHeight + root.Size.Y / 2
		local landing = spot + Vector3.new(0, height, 0)
		local rotation = root.CFrame.Rotation
		root.Anchored = true
		local elapsed = 0
		while elapsed < attack.LeapTime and enemy.Model.Parent do
			elapsed += RunService.Heartbeat:Wait()
			local t = math.min(1, elapsed / attack.LeapTime)
			local arc = math.sin(t * math.pi) * 12
			enemy.Model:PivotTo(CFrame.new(start:Lerp(landing, t) + Vector3.new(0, arc, 0)) * rotation)
		end
		if not enemies[enemy.Model] then
			return -- died mid-air; the death animation takes over
		end
		root.Anchored = false
		Remotes.EnemyFx:FireAllClients("Slam", spot, attack.Radius)
		for player, playerRoot in playersNear(spot, attack.Radius) do
			local away = flat(playerRoot.Position - spot)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
			hurtPlayer(enemy, player, attack.Damage, away * 40 + Vector3.new(0, 30, 0))
		end
	end)
end

-- Picks the next attack in the boss's pattern; returns it if the target is in range.
local function bossAttack(enemy: Enemy, targetRoot: BasePart): boolean
	local config = enemy.Config
	local name = config.Pattern[enemy.PatternIndex]
	local attack = config.Attacks[name]
	local distance = flat(targetRoot.Position - enemy.Root.Position).Magnitude
	if distance > attack.Range then
		return false
	end
	local now = os.clock()
	local busy = attack.Windup + (attack.LeapTime or 0)
	enemy.NextAttack = now + busy + config.AttackCooldown
	enemy.BusyUntil = now + busy + ATTACK_RECOVERY
	enemy.PatternIndex = enemy.PatternIndex % #config.Pattern + 1
	enemy.Humanoid:MoveTo(enemy.Root.Position)

	enemy.AttackToken += 1
	enemy.Model:SetAttribute("AttackKind", name)
	enemy.Model:SetAttribute("AttackWindup", attack.Windup)
	enemy.Model:SetAttribute("AttackLeap", attack.LeapTime or 0)
	enemy.Model:SetAttribute("AttackStart", workspace:GetServerTimeNow())
	if name == "Slam" then
		startSlam(enemy, attack, targetRoot, enemy.AttackToken)
	else
		startCleave(enemy, attack, targetRoot, enemy.AttackToken)
	end
	return true
end

local function findTarget(enemy: Enemy): Player?
	local best, bestDistance = nil, enemy.Config.AggroRange
	for _, player in Players:GetPlayers() do
		local root = livingRoot(player)
		if root and flat(root.Position - enemy.Area.Center).Magnitude <= enemy.Config.LeashRange then
			local distance = flat(root.Position - enemy.Root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = player, distance
			end
		end
	end
	return best
end

local function think(enemy: Enemy)
	local now = os.clock()
	local config = enemy.Config
	local humanoid = enemy.Humanoid
	local root = enemy.Root

	if (enemy.Model:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() then
		humanoid:MoveTo(root.Position)
		return
	end
	if now < enemy.BusyUntil then
		return
	end

	local fromHome = flat(root.Position - enemy.Area.Center).Magnitude
	if enemy.Returning then
		if fromHome < enemy.Area.Radius * 0.6 then
			enemy.Returning = false
		else
			humanoid.WalkSpeed = config.WalkSpeed
			humanoid:MoveTo(enemy.Area.Center)
			return
		end
	end

	local targetRoot = livingRoot(enemy.Target)
	if enemy.Target and not targetRoot then
		enemy.Target = nil -- target died or left
	end
	if targetRoot and (fromHome > config.LeashRange or flat(targetRoot.Position - enemy.Area.Center).Magnitude > config.LeashRange) then
		enemy.Target = nil
		enemy.Returning = true
		Damageable.Heal(enemy.Model)
		humanoid:MoveTo(enemy.Area.Center)
		return
	end

	if not enemy.Target then
		enemy.Target = findTarget(enemy)
		targetRoot = livingRoot(enemy.Target)
	end

	if enemy.Target and targetRoot then
		humanoid.WalkSpeed = config.WalkSpeed
		local distance = flat(targetRoot.Position - root.Position).Magnitude
		if config.Pattern then
			if now >= enemy.NextAttack and bossAttack(enemy, targetRoot) then
				return
			end
			if distance > config.AttackRange * 0.6 then
				humanoid:MoveTo(targetRoot.Position)
			else
				humanoid:MoveTo(root.Position)
			end
		elseif distance <= config.AttackRange and now >= enemy.NextAttack then
			startAttack(enemy, enemy.Target, targetRoot)
		elseif distance > config.AttackRange * 0.6 then
			humanoid:MoveTo(targetRoot.Position)
		else
			humanoid:MoveTo(root.Position)
		end
		return
	end

	-- Nothing to chase: wander around the spawn area.
	if now >= enemy.NextWander then
		humanoid.WalkSpeed = config.WanderSpeed
		humanoid:MoveTo(randomPointIn(enemy.Area))
		enemy.NextWander = now + rng:NextNumber(3, 7)
	end
end

-- A patch of dirt, a sign and props around the edge so each area is easy to find.
local function decorateArea(area: Area)
	local folder = Instance.new("Folder")
	folder.Name = area.Name
	folder.Parent = workspace

	local y = groundY(area.Center)
	Props.Place("DirtPad", Vector3.new(area.Center.X, y - 0.1, area.Center.Z), nil, folder, (area.Radius + 6) / 20)
	y += 0.2

	local clutter = Random.new(42)
	local list = area.Props or {}
	for i, name in list do
		local angle = i / #list * math.pi * 2 + clutter:NextNumber(-0.2, 0.2)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local spot = area.Center + outward * (area.Radius + clutter:NextNumber(3, 6))
		-- Tents open toward the middle; everything else gets a random turn.
		local facing = if name == "Tent"
			then -outward
			else Vector3.new(math.cos(clutter:NextNumber(0, 6.28)), 0, math.sin(clutter:NextNumber(0, 6.28)))
		Props.Place(name, Vector3.new(spot.X, y, spot.Z), facing, folder)
	end
	if area.CenterProp then
		Props.Place(area.CenterProp, Vector3.new(area.Center.X, y, area.Center.Z), nil, folder)
	end

	-- Sign on the side facing spawn.
	local toSpawn = flat(-area.Center)
	toSpawn = if toSpawn.Magnitude > 0.01 then toSpawn.Unit else Vector3.zAxis
	local signSpot = area.Center + toSpawn * (area.Radius + 9)
	Props.Sign(("%s  (Lv. %d)"):format(area.Name, Enemies.Types[area.Enemy].Level), Vector3.new(signSpot.X, y, signSpot.Z), toSpawn, folder)
end

-- Brings back any boss that's currently dead (Studio /spawnboss command).
function EnemyService.SpawnBosses(): number
	local count = 0
	for _, area in Enemies.SpawnAreas do
		local config = Enemies.Types[area.Enemy]
		if config.Boss and not bosses[area] then
			spawnEnemy(area)
			count += 1
		end
	end
	return count
end

function EnemyService.Start()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace

	for _, area in Enemies.SpawnAreas do
		local decorated, decorError = pcall(decorateArea, area)
		if not decorated then
			warn(("[EnemyService] Couldn't decorate %s: %s"):format(area.Name, tostring(decorError)))
		end
		for _ = 1, area.Count do
			local ok, err = pcall(spawnEnemy, area)
			if not ok then
				warn(("[EnemyService] Couldn't spawn %s: %s"):format(area.Enemy, tostring(err)))
			end
		end
	end

	task.spawn(function()
		while true do
			task.wait(THINK_INTERVAL)
			for _, enemy in enemies do
				local ok, err = pcall(think, enemy)
				if not ok then
					warn("[EnemyService] " .. tostring(err))
				end
			end
		end
	end)
end

return EnemyService
