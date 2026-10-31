-- Everything you see and feel when a hit lands: impact burst, shockwave
-- ring, dust, white flash, damage numbers, camera shake and the target
-- wobbling back.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

local HitEffects = {}

local effectsFolder: Folder

local function effectPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = effectsFolder
	return part
end

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

function HitEffects.Impact(position: Vector3, direction: Vector3, heavy: boolean)
	local scale = if heavy then 1.8 else 1

	-- Bright flash ball.
	local flash = effectPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 0.6,
		Color = Color3.fromRGB(255, 250, 230),
		Transparency = 0.1,
		CFrame = CFrame.new(position),
	})
	tween(flash, 0.14, { Size = Vector3.one * 3.2 * scale, Transparency = 1 })

	-- Shockwave ring facing along the punch.
	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.12, 1, 1),
		Color = Color3.fromRGB(255, 226, 150),
		Transparency = 0.25,
		CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0),
	})
	tween(ring, 0.28, { Size = Vector3.new(0.04, 6 * scale, 6 * scale), Transparency = 1 })

	-- A second, faster ring on heavy hits.
	if heavy then
		local ring2 = ring:Clone()
		ring2.Parent = effectsFolder
		ring2.CFrame = ring.CFrame * CFrame.new(-0.6, 0, 0)
		tween(ring2, 0.18, { Size = Vector3.new(0.04, 9, 9), Transparency = 1 })
		Debris:AddItem(ring2, 0.3)
	end

	-- Sparks and dust.
	local anchor = Instance.new("Attachment")
	anchor.WorldCFrame = CFrame.lookAt(position, position - direction)
	anchor.Parent = workspace.Terrain

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Enabled = false
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(255, 160, 60))
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5 * scale), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Speed = NumberRange.new(18 * scale, 34 * scale)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.Drag = 6
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Parent = anchor
	sparks:Emit(if heavy then 28 else 14)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = SMOKE_TEXTURE
	dust.Enabled = false
	dust.Color = ColorSequence.new(Color3.fromRGB(214, 190, 150))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8 * scale), NumberSequenceKeypoint.new(1, 3 * scale) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(0.35, 0.6)
	dust.Speed = NumberRange.new(3, 8 * scale)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Drag = 4
	dust.RotSpeed = NumberRange.new(-90, 90)
	dust.Rotation = NumberRange.new(0, 360)
	dust.Parent = anchor
	dust:Emit(if heavy then 12 else 6)

	Debris:AddItem(flash, 0.2)
	Debris:AddItem(ring, 0.35)
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
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "LocalEffects"
	effectsFolder.Parent = workspace

	RunService:BindToRenderStep("CombatCameraShake", Enum.RenderPriority.Camera.Value + 1, updateShake)
	RunService.RenderStepped:Connect(updateWobbles)
end

return HitEffects
