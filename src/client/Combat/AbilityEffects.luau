-- Draws gem moves for everyone: the fireball flying and exploding, the
-- flame dash trail, the expanding ring of fire, and the burst when someone
-- eats a gem. The server says what happened (Remotes.AbilityFx); this
-- only draws it. Other players' cast animations are played here too.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Images = require(ReplicatedStorage.Shared.Images)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Animator = require(script.Parent.Animator)
local HitEffects = require(script.Parent.HitEffects)

local player = Players.LocalPlayer

local FIRE_COLORS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 190)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 160, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 10)),
})
local FIRE_LIGHT = Color3.fromRGB(255, 140, 40)

local AbilityEffects = {}

local function sequence(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

local function anchorAt(cframe: CFrame): Attachment
	local a = Instance.new("Attachment")
	a.WorldCFrame = cframe
	a.Parent = workspace.Terrain
	return a
end

-- A flame emitter. Rate 0 means it's only used for bursts.
local function flames(parent: Instance, size: number, rate: number, speed: number?, lifetime: number?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Images.Get("FxFlame")
	e.Color = FIRE_COLORS
	e.LightEmission = 1
	e.Size = sequence(size, size * 0.2)
	e.Transparency = sequence(0.05, 1)
	e.Lifetime = NumberRange.new((lifetime or 0.35) * 0.7, lifetime or 0.35)
	e.Speed = NumberRange.new((speed or 3) * 0.5, speed or 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 8, 0)
	e.Rotation = NumberRange.new(-20, 20)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = rate
	e.LockedToPart = false
	e.Parent = parent
	return e
end

local function glow(parent: Instance, size: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = Images.Get("FxGlow")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90))
	e.LightEmission = 1
	e.Size = sequence(size, size * 1.3)
	e.Transparency = sequence(0.2, 1)
	e.Lifetime = NumberRange.new(0.15, 0.25)
	e.Speed = NumberRange.new(0)
	e.Rate = rate
	e.LockedToPart = true
	e.Parent = parent
	return e
end

local function light(parent: Instance, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = FIRE_LIGHT
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

-- Shake the camera if the local player is close to a blast.
local function nearbyShake(position: Vector3, strength: number, range: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local distance = (root.Position - position).Magnitude
	if distance < range then
		HitEffects.Shake(strength * (1 - distance / range), 0.3)
	end
end

local function explosion(position: Vector3, size: number)
	local anchor = anchorAt(CFrame.new(position))
	local burst = flames(anchor, 2.5 * size, 0, 22 * size, 0.5)
	burst.Drag = 5
	burst:Emit(36)
	local flash = glow(anchor, 6 * size, 0)
	flash.LockedToPart = false
	flash.Lifetime = NumberRange.new(0.2)
	flash:Emit(2)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = Images.Get("FxDust")
	smoke.Color = ColorSequence.new(Color3.fromRGB(70, 60, 55))
	smoke.Size = sequence(2 * size, 5 * size)
	smoke.Transparency = sequence(0.4, 1)
	smoke.Lifetime = NumberRange.new(0.8, 1.2)
	smoke.Speed = NumberRange.new(3, 7)
	smoke.SpreadAngle = Vector2.new(180, 180)
	smoke.Acceleration = Vector3.new(0, 4, 0)
	smoke.Drag = 2
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.Enabled = false
	smoke.Parent = anchor
	smoke:Emit(10)
	HitEffects.Impact(position, Vector3.yAxis, true)

	local l = light(anchor, 22 * size, 6)
	TweenService:Create(l, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	nearbyShake(position, 1.8 * size, 40)
	Debris:AddItem(anchor, 1.6)
end

local function playCast(caster: Player, animation: string)
	if caster ~= player and caster.Character then
		Animator.Play(caster.Character, animation)
	end
end

-- Fireball ------------------------------------------------------------------

type Projectile = { Part: BasePart, Position: Vector3, Direction: Vector3, Speed: number, Left: number }
local projectiles: { [string]: Projectile } = {}

local function key(caster: Player, id: number): string
	return caster.UserId .. ":" .. id
end

local function onFireball(caster: Player, id: number, origin: Vector3, direction: Vector3, speed: number, range: number, castTime: number)
	playCast(caster, "CastFireball")
	task.delay(castTime, function()
		local part = Instance.new("Part")
		part.Name = "Fireball"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.Size = Vector3.one
		part.CFrame = CFrame.new(origin)
		part.Parent = workspace
		glow(part, 4, 40)
		local trail = flames(part, 2.2, 90, 2, 0.3)
		trail.Acceleration = Vector3.zero
		light(part, 16, 4)
		projectiles[key(caster, id)] = { Part = part, Position = origin, Direction = direction, Speed = speed, Left = range }
		Debris:AddItem(part, range / speed + 1)
	end)
end

local function onFireballHit(caster: Player, id: number, at: Vector3)
	local k = key(caster, id)
	local projectile = projectiles[k]
	if projectile then
		projectile.Part:Destroy()
		projectiles[k] = nil
	end
	explosion(at, 1)
end

local function stepProjectiles(dt: number)
	for k, p in projectiles do
		if not p.Part.Parent then
			projectiles[k] = nil
			continue
		end
		local step = math.min(p.Speed * dt, p.Left)
		p.Position += p.Direction * step
		p.Left -= step
		p.Part.CFrame = CFrame.new(p.Position)
		if p.Left <= 0 then
			-- Wait for the server's explosion; just stop here.
			p.Speed = 0
		end
	end
end

-- Flame Dash ------------------------------------------------------------------

local function onFlameDash(caster: Player, start: Vector3, direction: Vector3, distance: number, dashTime: number)
	playCast(caster, "FlameDash")
	local root = caster.Character and caster.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local a = Instance.new("Attachment")
		a.Parent = root
		flames(a, 2.4, 120, 4, 0.4)
		light(a, 14, 3)
		Debris:AddItem(a, dashTime + 0.05)
	end
	-- Burning ground along the path for a moment.
	local groundY = start.Y - 2.6
	for d = 2, distance, 4 do
		task.delay(dashTime * d / distance, function()
			local spot = start + direction * d
			local anchor = anchorAt(CFrame.new(spot.X, groundY, spot.Z))
			local e = flames(anchor, 1.6, 25, 2, 0.45)
			e.SpreadAngle = Vector2.new(25, 25)
			e.EmissionDirection = Enum.NormalId.Top
			task.delay(1.1, function()
				e.Enabled = false
			end)
			Debris:AddItem(anchor, 1.7)
		end)
	end
end

-- Fire Ring ---------------------------------------------------------------------

local function onFireRing(caster: Player, origin: Vector3, radius: number, castTime: number)
	playCast(caster, "FireRing")
	-- Embers gather around the caster while they crouch.
	local gather = anchorAt(CFrame.new(origin))
	local embers = glow(gather, 0.8, 50)
	embers.LockedToPart = false
	embers.Speed = NumberRange.new(-8, -6)
	embers.SpreadAngle = Vector2.new(180, 180)
	embers.Lifetime = NumberRange.new(0.3)
	Debris:AddItem(gather, castTime + 0.3)
	task.delay(castTime, function()
		embers.Enabled = false
		local groundY = origin.Y - 2.6
		local count = 28
		local expand = 0.35
		for i = 1, count do
			local angle = i / count * math.pi * 2
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local anchor = anchorAt(CFrame.new(origin.X, groundY, origin.Z) + outward * 1.5)
			local e = flames(anchor, 2.6, 60, 4, 0.4)
			e.SpreadAngle = Vector2.new(30, 30)
			e.EmissionDirection = Enum.NormalId.Top
			TweenService:Create(anchor, TweenInfo.new(expand, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				WorldPosition = Vector3.new(origin.X, groundY, origin.Z) + outward * radius,
			}):Play()
			task.delay(expand + 0.25, function()
				e.Enabled = false
			end)
			Debris:AddItem(anchor, expand + 1)
		end
		local center = anchorAt(CFrame.new(origin))
		local ring = Instance.new("ParticleEmitter")
		ring.Texture = Images.Get("FxRing")
		ring.Color = ColorSequence.new(Color3.fromRGB(255, 170, 60))
		ring.LightEmission = 1
		ring.Size = sequence(2, radius * 2.2)
		ring.Transparency = sequence(0.1, 1)
		ring.Lifetime = NumberRange.new(expand + 0.1)
		ring.Speed = NumberRange.new(0)
		ring.Enabled = false
		ring.Parent = center
		ring:Emit(1)
		local l = light(center, radius * 1.6, 7)
		TweenService:Create(l, TweenInfo.new(0.8), { Brightness = 0 }):Play()
		Debris:AddItem(center, 1.2)
		nearbyShake(origin, 2.2, radius * 2.5)
	end)
end

-- Gem eaten -----------------------------------------------------------------------

local function onGemEaten(eater: Player, _gemId: string)
	local root = eater.Character and eater.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local a = Instance.new("Attachment")
	a.Parent = root
	local burst = flames(a, 2, 0, 12, 0.6)
	burst:Emit(40)
	local swirl = flames(a, 1.2, 60, 1, 0.5)
	light(a, 16, 5)
	task.delay(0.8, function()
		swirl.Enabled = false
	end)
	Debris:AddItem(a, 1.5)
	if eater == player then
		HitEffects.Shake(0.8, 0.3)
	end
end

local HANDLERS = {
	Fireball = onFireball,
	FireballHit = onFireballHit,
	FlameDash = onFlameDash,
	FireRing = onFireRing,
	GemEaten = onGemEaten,
}

function AbilityEffects.Start()
	Remotes.AbilityFx.OnClientEvent:Connect(function(kind: string, ...)
		local handler = HANDLERS[kind]
		if handler then
			handler(...)
		end
	end)
	RunService.RenderStepped:Connect(stepProjectiles)
end

return AbilityEffects
