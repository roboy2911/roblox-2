-- Spawns enemies in their spawn areas and runs their behavior:
--   wander around the area -> notice a nearby player -> chase -> bite
--   -> die, give XP and gold -> respawn 15 seconds later
-- Enemies that get dragged too far from home walk back and heal.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Damageable = require(script.Parent.Damageable)
local EnemyRig = require(script.Parent.EnemyRig)
local LevelingService = require(script.Parent.LevelingService)

local ENEMY_TAG = "Enemy"
local THINK_INTERVAL = 0.1
local REWARD_SHARE = 0.1 -- players who dealt at least 10% of max HP get the reward
local BITE_RECOVERY = 0.3 -- stands still this long after biting

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
}

local EnemyService = {}

local enemiesFolder: Folder
local enemies: { [Model]: Enemy } = {}
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
	enemy.Root.AssemblyLinearVelocity = direction * (if heavy then 34 else 12) + Vector3.new(0, if heavy then 32 else 6, 0)
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
		end
	end
end

-- Flips over, then fades away.
local function playDeath(model: Model, root: BasePart)
	root.Anchored = true
	local start = model:GetPivot()
	local roll = Instance.new("NumberValue")
	roll.Changed:Connect(function(value)
		if model.Parent then
			model:PivotTo(start * CFrame.new(0, value / 180 * 0.4, 0) * CFrame.Angles(0, 0, math.rad(value)))
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
	cancelAttack(enemy)
	giveRewards(enemy, contributors)
	playDeath(enemy.Model, enemy.Root)
	task.delay(enemy.Config.RespawnTime, spawnEnemy, enemy.Area)
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
	model:SetAttribute("HitRadius", config.Length * 0.35)
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
	}
	enemies[model] = enemy

	Damageable.OnDamaged(model, function(_, _, attacker, info)
		cancelAttack(enemy)
		knockback(enemy, attacker, info.Heavy == true)
		if attacker and not enemy.Returning then
			enemy.Target = attacker
		end
	end)
	Damageable.OnDied(model, function(_, contributors)
		onDied(enemy, contributors)
	end)
end

local function bite(enemy: Enemy, target: Player, token: number)
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
	enemy.BusyUntil = now + config.AttackWindup + BITE_RECOVERY
	enemy.Humanoid:MoveTo(enemy.Root.Position)

	local position = enemy.Root.Position
	enemy.Root.CFrame = CFrame.lookAt(position, Vector3.new(targetRoot.Position.X, position.Y, targetRoot.Position.Z))

	enemy.AttackToken += 1
	local token = enemy.AttackToken
	enemy.Model:SetAttribute("AttackStart", workspace:GetServerTimeNow()) -- clients play the rear-back-and-bite
	task.delay(config.AttackWindup, bite, enemy, target, token)
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
		if distance <= config.AttackRange and now >= enemy.NextAttack then
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

-- A patch of dirt, a sign and some clutter so each area is easy to find.
local function decorateArea(area: Area)
	local folder = Instance.new("Folder")
	folder.Name = area.Name
	folder.Parent = workspace

	local y = groundY(area.Center)
	local function part(props: { [string]: any })
		local p = Instance.new("Part")
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = folder
		return p
	end

	part({
		Name = "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, (area.Radius + 6) * 2, (area.Radius + 6) * 2),
		CFrame = CFrame.new(area.Center.X, y + 0.05, area.Center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(104, 92, 64),
		Material = Enum.Material.Ground,
		CanCollide = false,
	})

	local clutter = Random.new(42)
	for i = 1, 7 do
		local angle = i / 7 * math.pi * 2 + clutter:NextNumber(-0.2, 0.2)
		local spot = area.Center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (area.Radius + clutter:NextNumber(2, 5))
		if i % 2 == 0 then
			part({
				Name = "Barrel",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(2.6, 2, 2),
				CFrame = CFrame.new(spot.X, y + 1.3, spot.Z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(110, 72, 40),
				Material = Enum.Material.Wood,
			})
		else
			part({
				Name = "HayBale",
				Size = Vector3.new(3, 2, 2),
				CFrame = CFrame.new(spot.X, y + 1, spot.Z) * CFrame.Angles(0, angle, 0),
				Color = Color3.fromRGB(214, 184, 96),
				Material = Enum.Material.Grass,
			})
		end
	end

	-- Sign on the side facing spawn.
	local toSpawn = flat(-area.Center)
	toSpawn = if toSpawn.Magnitude > 0.01 then toSpawn.Unit else Vector3.zAxis
	local signSpot = area.Center + toSpawn * (area.Radius + 8)
	part({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), Position = Vector3.new(signSpot.X, y + 2.5, signSpot.Z), Color = Color3.fromRGB(92, 58, 32), Material = Enum.Material.Wood })
	local board = part({
		Name = "SignBoard",
		Size = Vector3.new(7, 2.5, 0.4),
		CFrame = CFrame.lookAt(Vector3.new(signSpot.X, y + 5, signSpot.Z), Vector3.new(signSpot.X, y + 5, signSpot.Z) + toSpawn),
		Color = Color3.fromRGB(120, 80, 45),
		Material = Enum.Material.Wood,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fantasy
		label.Text = ("%s  (Lv. %d)"):format(area.Name, Enemies.Types[area.Enemy].Level)
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 236, 190)
		label.Parent = gui
	end
end

function EnemyService.Start()
	enemiesFolder = Instance.new("Folder")
	enemiesFolder.Name = "Enemies"
	enemiesFolder.Parent = workspace

	for _, area in Enemies.SpawnAreas do
		decorateArea(area)
		for _ = 1, area.Count do
			spawnEnemy(area)
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
