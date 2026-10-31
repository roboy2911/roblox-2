-- Turns an enemy model into something that can walk around: adds a
-- HumanoidRootPart and a Humanoid, and joins each body part with a Motor6D
-- (named "Joint", inside the part) so clients can animate it.
--
-- Two kinds of rig, set by Rig in Config/Enemies:
--   Quadruped (rat):  Body, Head, Tail, LegFL, LegFR, LegBL, LegBR
--   Biped (bandit):   Torso, Head, ArmL, ArmR, LegL, LegR
--
-- Built once per enemy type, then cloned for each spawn. If the model can't
-- be loaded, a stand-in is built from blocks.

local AssetService = require(script.Parent.AssetService)

local EnemyRig = {}

local templates: { [string]: Model } = {}

-- How long a part is along a world direction.
local function extentAlong(part: BasePart, direction: Vector3): number
	local cf, size = part.CFrame, part.Size
	return math.abs(cf.RightVector:Dot(direction)) * size.X
		+ math.abs(cf.UpVector:Dot(direction)) * size.Y
		+ math.abs(cf.LookVector:Dot(direction)) * size.Z
end

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

local function block(model: Model, name: string, size: Vector3, position: Vector3, color: Color3, ball: boolean?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if ball then
		part.Shape = Enum.PartType.Ball
	end
	part.Parent = model
end

-- Stand-ins (face -Z), only used if the real model can't be loaded.
local function fallbackQuadruped(model: Model)
	local fur, pink = Color3.fromRGB(77, 66, 60), Color3.fromRGB(219, 143, 143)
	block(model, "Body", Vector3.new(1.2, 1, 2.4), Vector3.new(0, 0.8, 0.2), fur)
	block(model, "Head", Vector3.new(0.9, 0.8, 1.3), Vector3.new(0, 0.9, -1.15), fur)
	block(model, "Tail", Vector3.new(0.16, 0.16, 2), Vector3.new(0, 0.55, 2.2), pink)
	for _, leg in { { "LegFL", -0.36, -0.5 }, { "LegFR", 0.36, -0.5 }, { "LegBL", -0.4, 0.55 }, { "LegBR", 0.4, 0.55 } } do
		block(model, leg[1], Vector3.new(0.26, 0.5, 0.3), Vector3.new(leg[2], 0.25, leg[3]), fur)
	end
end

local function fallbackBiped(model: Model)
	local shirt, skin, pants = Color3.fromRGB(115, 95, 72), Color3.fromRGB(189, 133, 97), Color3.fromRGB(61, 56, 51)
	block(model, "Torso", Vector3.new(1.6, 1.9, 0.9), Vector3.new(0, 3.3, 0), shirt)
	block(model, "Head", Vector3.new(0.95, 0.95, 0.95), Vector3.new(0, 4.72, 0), skin, true)
	block(model, "ArmL", Vector3.new(0.45, 1.9, 0.45), Vector3.new(-0.98, 3.2, 0), skin)
	block(model, "ArmR", Vector3.new(0.45, 1.9, 0.45), Vector3.new(0.98, 3.2, 0), skin)
	block(model, "LegL", Vector3.new(0.6, 2.3, 0.6), Vector3.new(-0.38, 1.15, 0), pants)
	block(model, "LegR", Vector3.new(0.6, 2.3, 0.6), Vector3.new(0.38, 1.15, 0), pants)
end

-- Where each part turns: legs and arms at the top, the head at the neck,
-- the tail at its base.
local function jointPoint(part: BasePart, rig: string, forward: Vector3, bodyName: string): Vector3
	local name = part.Name
	local up = Vector3.yAxis
	local pivot = part.Position
	if rig == "Biped" and name == bodyName then
		pivot -= up * extentAlong(part, up) * 0.45 -- twist at the waist
	elseif string.find(name, "^Leg") then
		pivot += up * extentAlong(part, up) * (if rig == "Biped" then 0.45 else 0.4)
	elseif string.find(name, "^Arm") then
		pivot += up * extentAlong(part, up) * 0.42
	elseif string.find(name, "^Tail") then
		pivot += forward * extentAlong(part, forward) * 0.5
	elseif name == "Head" then
		if rig == "Biped" then
			pivot -= up * extentAlong(part, up) * 0.45
		else
			pivot -= forward * extentAlong(part, forward) * 0.35
		end
	end
	return pivot
end

local function build(typeName: string, config): Model
	local rig = config.Rig or "Quadruped"
	local bodyName = config.BodyPart or "Body"

	local model = AssetService.Model(config.Model)
	if not model or not model:FindFirstChild(bodyName) or not model:FindFirstChild("Head") then
		model = Instance.new("Model")
		if rig == "Biped" then
			fallbackBiped(model)
		else
			fallbackQuadruped(model)
		end
	end
	model.Name = config.DisplayName

	-- Scale: bipeds by height, four-legged enemies by length.
	local _, size = model:GetBoundingBox()
	if config.Height then
		model:ScaleTo(model:GetScale() * config.Height / size.Y)
	else
		model:ScaleTo(model:GetScale() * config.Length / math.max(size.X, size.Z))
	end

	local body = model:FindFirstChild(bodyName) :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local forward = -Vector3.zAxis -- models face -Z
	if rig == "Quadruped" then
		local toHead = flat(head.Position - body.Position)
		if toHead.Magnitude > 0.01 then
			forward = toHead.Unit
		end
	end
	local right = forward:Cross(Vector3.yAxis)

	local bottom, top = math.huge, -math.huge
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local half = extentAlong(part, Vector3.yAxis) / 2
			bottom = math.min(bottom, part.Position.Y - half)
			top = math.max(top, part.Position.Y + half)
		end
	end

	-- Root part: an invisible box inside the body. The Humanoid holds it
	-- HipHeight above the ground, which puts the feet on the floor.
	local centerY = body.Position.Y
	local rootHeight = extentAlong(body, Vector3.yAxis) * 0.6
	if centerY - rootHeight / 2 - bottom < 0.05 then
		rootHeight = math.max(0.3, 2 * (centerY - bottom - 0.05))
	end
	local rootPosition = Vector3.new(body.Position.X, centerY, body.Position.Z)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(extentAlong(body, right) * 0.85, rootHeight, extentAlong(body, forward) * 0.85)
	root.CFrame = CFrame.lookAt(rootPosition, rootPosition + forward)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model

	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") or part == root then
			continue
		end
		local jointFrame = CFrame.new(jointPoint(part, rig, forward, bodyName)) * root.CFrame.Rotation
		-- A biped's arms and head hang off the torso, so they turn with it.
		local onTorso = rig == "Biped" and (part.Name == "Head" or string.find(part.Name, "^Arm") ~= nil)
		local parent = if onTorso then body else root
		local joint = Instance.new("Motor6D")
		joint.Name = "Joint"
		joint.Part0 = parent
		joint.Part1 = part
		joint.C0 = parent.CFrame:ToObjectSpace(jointFrame)
		joint.C1 = part.CFrame:ToObjectSpace(jointFrame)
		joint.Parent = part

		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = math.max(0, centerY - rootHeight / 2 - bottom)
	humanoid.WalkSpeed = config.WalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("EnemyType", typeName)
	model:SetAttribute("Rig", rig)
	-- Heights measured from the root's center (the model's pivot).
	model:SetAttribute("TemplateBarHeight", top - centerY + 1.2)
	model:SetAttribute("TemplateHitHeight", (top - centerY) * (if rig == "Biped" then 0.15 else 0.35))
	return model
end

-- Returns the template for an enemy type (built on first use).
function EnemyRig.Get(typeName: string, config): Model
	if not templates[typeName] then
		templates[typeName] = build(typeName, config)
	end
	return templates[typeName]
end

return EnemyRig
