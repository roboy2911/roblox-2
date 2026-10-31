-- Turns an uploaded enemy model into something that can walk around:
-- adds a HumanoidRootPart and a Humanoid, and joins each body part with a
-- Motor6D (named "Joint", inside the part) so clients can animate the legs,
-- tail and head. Built once per enemy type, then cloned for each spawn.
-- If the model can't be loaded, a simple one is built from parts.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local EnemyRig = {}

local FUR = { Color = Color3.fromRGB(77, 66, 60), Material = Enum.Material.Fabric }
local PINK = { Color = Color3.fromRGB(219, 143, 143), Material = Enum.Material.SmoothPlastic }
local EYE = { Color = Color3.fromRGB(10, 10, 10), Material = Enum.Material.Glass }

-- Part name pattern -> look. First match wins.
local PART_STYLES = {
	{ "^Eye", EYE },
	{ "^Ear", PINK },
	{ "^Nose", PINK },
	{ "^Tail", PINK },
	{ "", FUR },
}

-- These parts are attached to the head so they move with it.
local HEAD_PARTS = { "^Eye", "^Ear", "^Nose" }

local templates: { [string]: Model } = {}

local function matches(name: string, patterns: { string }): boolean
	for _, pattern in patterns do
		if string.find(name, pattern) then
			return true
		end
	end
	return false
end

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

local function loadParts(assetName: string, into: Model): boolean
	local assetId = Assets[assetName]
	if not assetId then
		return false
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok then
		warn(("[EnemyRig] Could not load %s model, using a simple one instead: %s"):format(assetName, tostring(container)))
		return false
	end
	for _, part in container:GetDescendants() do
		if part:IsA("BasePart") then
			part.Parent = into
		end
	end
	container:Destroy()
	return into:FindFirstChild("Body") ~= nil and into:FindFirstChild("Head") ~= nil
end

local function blob(model: Model, name: string, size: Vector3, position: Vector3, shape: Enum.PartType?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		part.Shape = shape
	else
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = model
	return part
end

-- Simple rat made of parts (faces -Z), used if the mesh can't be loaded.
local function buildFallbackRat(model: Model)
	blob(model, "Body", Vector3.new(1.2, 1.05, 2.4), Vector3.new(0, 0.8, 0.2))
	blob(model, "Head", Vector3.new(0.9, 0.85, 1.3), Vector3.new(0, 0.9, -1.15))
	blob(model, "Nose", Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, 0.82, -1.82), Enum.PartType.Ball)
	blob(model, "Eyes", Vector3.new(0.22, 0.22, 0.22), Vector3.new(0.3, 1.06, -1.3), Enum.PartType.Ball)
	blob(model, "Eyes2", Vector3.new(0.22, 0.22, 0.22), Vector3.new(-0.3, 1.06, -1.3), Enum.PartType.Ball)
	blob(model, "Ears", Vector3.new(0.48, 0.48, 0.17), Vector3.new(0.3, 1.3, -0.85))
	blob(model, "Ears2", Vector3.new(0.48, 0.48, 0.17), Vector3.new(-0.3, 1.3, -0.85))
	local tail = blob(model, "Tail", Vector3.new(2, 0.16, 0.16), Vector3.zero, Enum.PartType.Cylinder)
	tail.CFrame = CFrame.new(0, 0.55, 2.2) * CFrame.Angles(0, math.rad(90), math.rad(-10))
	for _, leg in { { "LegFL", -0.36, -0.5 }, { "LegFR", 0.36, -0.5 }, { "LegBL", -0.4, 0.55 }, { "LegBR", 0.4, 0.55 } } do
		blob(model, leg[1], Vector3.new(0.26, 0.5, 0.3), Vector3.new(leg[2], 0.25, leg[3]), Enum.PartType.Block)
	end
end

local function build(typeName: string, config): Model
	local model = Instance.new("Model")
	model.Name = config.DisplayName
	if not loadParts(config.Model, model) then
		model:ClearAllChildren()
		buildFallbackRat(model)
	end

	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			for _, entry in PART_STYLES do
				if string.find(part.Name, entry[1]) then
					part.Color = entry[2].Color
					part.Material = entry[2].Material
					break
				end
			end
		end
	end

	-- Scale so the longest side matches the configured length.
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * config.Length / math.max(size.X, size.Z))

	local body = model:FindFirstChild("Body") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	local forward = flat(head.Position - body.Position)
	forward = if forward.Magnitude > 0.01 then forward.Unit else -Vector3.zAxis
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
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(extentAlong(body, right) * 0.85, rootHeight, extentAlong(body, forward) * 0.85)
	root.CFrame = CFrame.lookAt(Vector3.new(body.Position.X, centerY, body.Position.Z), Vector3.new(body.Position.X, centerY, body.Position.Z) + forward)
	root.Transparency = 1
	root.CanCollide = true
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model

	-- Joints. Each one turns around a sensible point: legs at the hip, the
	-- tail at its base, the head at the neck.
	for _, part in model:GetChildren() do
		if not part:IsA("BasePart") or part == root then
			continue
		end
		local name = part.Name
		local pivot = part.Position
		if string.find(name, "^Leg") then
			pivot += Vector3.yAxis * extentAlong(part, Vector3.yAxis) * 0.4
		elseif string.find(name, "^Tail") then
			pivot += forward * extentAlong(part, forward) * 0.5
		elseif name == "Head" then
			pivot -= forward * extentAlong(part, forward) * 0.35
		end
		local jointFrame = CFrame.new(pivot) * root.CFrame.Rotation
		local parent = if matches(name, HEAD_PARTS) then head else root

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
	-- Heights measured from the root's center (the model's pivot).
	model:SetAttribute("TemplateBarHeight", top - centerY + 1.2)
	model:SetAttribute("TemplateHitHeight", (top - centerY) * 0.35)
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
