-- Everything you see and feel when a hit lands: impact burst, shockwave
-- ring, dust, white flash, damage numbers, camera shake and the target
-- wobbling back.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Shared.Images)

local player = Players.LocalPlayer


local HitEffects = {}

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Where on the target the hit lands: its chest, on the side facing the attacker.
function HitEffects.HitPoint(target: Model, attackerPosition: Vector3): (Vector3, Vector3)
	local base = target:GetPivot().Position
	local direction = (base - attackerPosition) * Vector3.new(1, 0, 1)
	direction = if direction.Magnitude > 0.01 then direction.Unit else Vector3.zAxis
	local height = target:GetAttribute("HitHeight") or 3
	return base + Vector3.new(0, height, 0) - direction * 0.9, direction
end

-- One burst of particles from an attachment, using one of our images.
local function burst(anchor: Attachment, props: { [string]: any }, count: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.LockedToPart = false
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = anchor
	emitter:Emit(count)
end

local function sequence(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

function HitEffects.Impact(position: Vector3, direction: Vector3, heavy: boolean)
	local scale = if heavy then 1.8 else 1
	local anchor = Instance.new("Attachment")
	anchor.WorldCFrame = CFrame.lookAt(position, position - direction)
	anchor.Parent = workspace.Terrain

	-- Bright flash.
	burst(anchor, {
		Texture = Images.Get("FxGlow"),
		Color = ColorSequence.new(Color3.fromRGB(255, 250, 230)),
		LightEmission = 1,
		Size = sequence(0.8 * scale, 4 * scale),
		Transparency = sequence(0, 1),
		Lifetime = NumberRange.new(0.14),
		Speed = NumberRange.new(0),
	}, 1)

	-- Shockwave ring.
	burst(anchor, {
		Texture = Images.Get("FxRing"),
		Color = ColorSequence.new(Color3.fromRGB(255, 226, 150)),
		LightEmission = 0.8,
		Size = sequence(0.6, 6 * scale),
		Transparency = sequence(0.1, 1),
		Lifetime = NumberRange.new(0.28),
		Speed = NumberRange.new(0),
		Rotation = NumberRange.new(0, 360),
	}, 1)
	if heavy then
		burst(anchor, {
			Texture = Images.Get("FxRing"),
			Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)),
			LightEmission = 1,
			Size = sequence(1, 10),
			Transparency = sequence(0.2, 1),
			Lifetime = NumberRange.new(0.18),
			Speed = NumberRange.new(0),
		}, 1)
	end

	-- Sparks flying out of the hit.
	burst(anchor, {
		Texture = Images.Get("FxSpark"),
		LightEmission = 1,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 160, 60)),
		Size = sequence(0.6 * scale, 0),
		Lifetime = NumberRange.new(0.15, 0.3),
		Speed = NumberRange.new(18 * scale, 34 * scale),
		SpreadAngle = Vector2.new(70, 70),
		Drag = 6,
		Acceleration = Vector3.new(0, -30, 0),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
	}, if heavy then 28 else 14)

	-- Dust puff.
	burst(anchor, {
		Texture = Images.Get("FxDust"),
		Color = ColorSequence.new(Color3.fromRGB(214, 190, 150)),
		Size = sequence(0.8 * scale, 3 * scale),
		Transparency = sequence(0.35, 1),
		Lifetime = NumberRange.new(0.35, 0.6),
		Speed = NumberRange.new(3, 8 * scale),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
		RotSpeed = NumberRange.new(-90, 90),
		Rotation = NumberRange.new(0, 360),
	}, if heavy then 12 else 6)

	Debris:AddItem(anchor, 1)
end

function HitEffects.Flash(target: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.2
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0.4
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target
	tween(highlight, 0.2, { FillTransparency = 1, OutlineTransparency = 1 })
	Debris:AddItem(highlight, 0.22)
end

function HitEffects.DamageNumber(position: Vector3, amount: number, big: boolean)
	local start = position + Vector3.new((math.random() - 0.5) * 2, 0.6 + math.random() * 0.6, (math.random() - 0.5) * 1.2)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = start
	anchor.Parent = workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 60)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = player:WaitForChild("PlayerGui")

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Fantasy
	text.Text = tostring(amount)
	text.TextSize = if big then 40 else 30
	text.TextColor3 = if big then Color3.fromRGB(255, 196, 64) else Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.1
	text.Parent = gui

	-- Pop in big, settle, then float up and fade.
	local pop = Instance.new("UIScale")
	pop.Scale = 1.9
	pop.Parent = text
	tween(pop, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(anchor, 0.8, { WorldPosition = start + Vector3.new(0, 2.5, 0) })
	task.delay(0.35, function()
		tween(text, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(gui, 0.85)
	Debris:AddItem(anchor, 0.85)
end

-- Text that floats up from a spot in the world and fades (rewards, etc).
function HitEffects.FloatingText(position: Vector3, message: string, color: Color3, size: number, delay: number?)
	task.delay(delay or 0, function()
		local anchor = Instance.new("Attachment")
		anchor.WorldPosition = position
		anchor.Parent = workspace.Terrain

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(220, 50)
		gui.AlwaysOnTop = true
		gui.Adornee = anchor
		gui.Parent = player:WaitForChild("PlayerGui")

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Fantasy
		text.Text = message
		text.TextSize = size
		text.TextColor3 = color
		text.TextStrokeTransparency = 0.2
		text.Parent = gui

		local pop = Instance.new("UIScale")
		pop.Scale = 0.4
		pop.Parent = text
		tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(anchor, 1.6, { WorldPosition = position + Vector3.new(0, 3, 0) })
		task.delay(0.9, function()
			tween(text, 0.7, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end)
		Debris:AddItem(gui, 1.7)
		Debris:AddItem(anchor, 1.7)
	end)
end

-- Camera shake ------------------------------------------------------------

local shakes: { { Strength: number, Duration: number, Age: number } } = {}

function HitEffects.Shake(strength: number, duration: number)
	table.insert(shakes, { Strength = strength, Duration = duration, Age = 0 })
end

local function updateShake(dt: number)
	if #shakes == 0 then
		return
	end
	local total = 0
	for i = #shakes, 1, -1 do
		local shake = shakes[i]
		shake.Age += dt
		if shake.Age >= shake.Duration then
			table.remove(shakes, i)
		else
			local fade = 1 - shake.Age / shake.Duration
			total += shake.Strength * fade * fade
		end
	end
	local t = os.clock() * 40
	local camera = workspace.CurrentCamera
	camera.CFrame *= CFrame.Angles(
		math.rad(math.noise(t, 0) * total * 2),
		math.rad(math.noise(0, t) * total * 2),
		math.rad(math.noise(t, t) * total)
	)
end

-- Target wobble -------------------------------------------------------------
-- Tips the target away from the hit and springs it back. Only used on
-- anchored targets like dummies.

type Wobble = { Base: CFrame, Axis: Vector3, Amount: number, Age: number }
local wobbles: { [Model]: Wobble } = {}

function HitEffects.Wobble(target: Model, direction: Vector3, heavy: boolean)
	if target:GetAttribute("Dead") then
		return
	end
	local root = target.PrimaryPart
	if not root or not root.Anchored then
		return
	end
	local existing = wobbles[target]
	wobbles[target] = {
		Base = if existing then existing.Base else target:GetPivot(),
		Axis = Vector3.yAxis:Cross(direction).Unit,
		Amount = math.rad(if heavy then 22 else 11),
		Age = 0,
	}
end

local function updateWobbles(dt: number)
	for target, wobble in wobbles do
		wobble.Age += dt
		local t = wobble.Age
		if not target.Parent or target:GetAttribute("Dead") then
			wobbles[target] = nil -- the server's tip-over takes over
		elseif t > 0.7 then
			target:PivotTo(wobble.Base)
			wobbles[target] = nil
		else
			local angle = wobble.Amount * math.exp(-6 * t) * math.sin(t * 24 + 0.35)
			local base = wobble.Base
			target:PivotTo(CFrame.new(base.Position) * CFrame.fromAxisAngle(wobble.Axis, angle) * base.Rotation)
		end
	end
end

function HitEffects.Start()
	RunService:BindToRenderStep("CombatCameraShake", Enum.RenderPriority.Camera.Value + 1, updateShake)
	RunService.RenderStepped:Connect(updateWobbles)
end

return HitEffects
