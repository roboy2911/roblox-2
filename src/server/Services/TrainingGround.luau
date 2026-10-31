-- Builds the training ground at game start: a dirt pad, a sign and a row of
-- training dummies. The dummy mesh is loaded from the uploaded Blender model;
-- if that fails (e.g. the place is not owned by the same account), a simple
-- dummy is built from parts so testing still works.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Damageable = require(script.Parent.Damageable)
local LevelingService = require(script.Parent.LevelingService)

local CENTER = Vector3.new(0, 0, 40) -- training ground spot, away from spawn
local DUMMY_COUNT = 3
local DUMMY_SPACING = 9
local DUMMY_HEIGHT = 6
local DUMMY_HEALTH = 300
local DUMMY_XP = 40
local RESPAWN_DELAY = 3

local PART_STYLES = {
	Post = { Color = Color3.fromRGB(92, 58, 32), Material = Enum.Material.Wood },
	Body = { Color = Color3.fromRGB(204, 173, 97), Material = Enum.Material.Fabric },
	Head = { Color = Color3.fromRGB(158, 128, 87), Material = Enum.Material.Fabric },
	Rope = { Color = Color3.fromRGB(140, 38, 31), Material = Enum.Material.Fabric },
}

local TrainingGround = {}

local function makePart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Finds the top of whatever is under a point; makes a floor if there's nothing.
local function groundHeightAt(position: Vector3, folder: Folder): number
	local result = workspace:Raycast(position + Vector3.new(0, 500, 0), Vector3.new(0, -1000, 0))
	if result then
		return result.Position.Y
	end
	makePart({
		Name = "Floor",
		Size = Vector3.new(120, 2, 120),
		Position = Vector3.new(position.X, -1, position.Z),
		Color = Color3.fromRGB(86, 140, 62),
		Material = Enum.Material.Grass,
		Parent = folder,
	})
	return 0
end

-- Loads the Blender mesh once. Returns nil if it can't be loaded.
local function loadDummyTemplate(): Instance?
	local ok, container = pcall(function()
		return InsertService:LoadAsset(Assets.TrainingDummy)
	end)
	if not ok then
		warn("[TrainingGround] Could not load dummy model, using a simple one instead: " .. tostring(container))
		return nil
	end
	return container
end

local function buildFallbackParts(model: Model)
	makePart({ Name = "Post", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 0.4, 0.4), CFrame = CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Parent = model })
	makePart({ Name = "PostFeet", Size = Vector3.new(2.2, 0.25, 0.35), Position = Vector3.new(0, 0.125, 0), Parent = model })
	makePart({ Name = "PostFeet2", Size = Vector3.new(0.35, 0.25, 2.2), Position = Vector3.new(0, 0.125, 0), Parent = model })
	makePart({ Name = "PostArms", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 0.25, 0.25), Position = Vector3.new(0, 4.1, 0), Parent = model })
	makePart({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 1.6, 1.6), CFrame = CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)), Parent = model })
	makePart({ Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.25, 1.25, 1.25), Position = Vector3.new(0, 5.15, 0), Parent = model })
end

local function styleParts(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = true
			for name, style in PART_STYLES do
				if string.find(part.Name, name) then
					part.Color = style.Color
					part.Material = style.Material
					break
				end
			end
		end
	end
end

local function createDummy(template: Instance?, index: number): Model
	local model = Instance.new("Model")
	model.Name = "Training Dummy"

	if template then
		for _, part in template:Clone():GetDescendants() do
			if part:IsA("BasePart") then
				part.Parent = model
			end
		end
	end
	if not model:FindFirstChildWhichIsA("BasePart") then
		buildFallbackParts(model)
	end
	styleParts(model)

	-- Scale to a fixed height, then add an invisible root at the base.
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * DUMMY_HEIGHT / size.Y)
	local boxCFrame, boxSize = model:GetBoundingBox()

	local root = makePart({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = model,
	})
	model.PrimaryPart = root

	model:SetAttribute("Index", index)
	return model
end

-- Tips the dummy over when it's defeated, and stands it back up after.
local function tip(model: Model, standing: CFrame, down: boolean)
	local angle = Instance.new("NumberValue")
	angle.Value = if down then 0 else 75
	angle.Changed:Connect(function(value)
		if model.Parent then
			model:PivotTo(standing * CFrame.Angles(math.rad(-value), 0, 0))
		end
	end)
	local tween = TweenService:Create(
		angle,
		TweenInfo.new(if down then 0.35 else 0.5, if down then Enum.EasingStyle.Quad else Enum.EasingStyle.Back),
		{ Value = if down then 75 else 0 }
	)
	tween.Completed:Once(function()
		angle:Destroy()
	end)
	tween:Play()
end

local function buildSign(folder: Folder, groundY: number)
	local base = CENTER + Vector3.new(-16, groundY, -10)
	makePart({ Name = "SignPost", Size = Vector3.new(0.5, 5, 0.5), Position = base + Vector3.new(0, 2.5, 0), Color = PART_STYLES.Post.Color, Material = Enum.Material.Wood, Parent = folder })
	local board = makePart({
		Name = "SignBoard",
		Size = Vector3.new(7, 2.5, 0.4),
		CFrame = CFrame.new(base + Vector3.new(0, 5, 0)) * CFrame.Angles(0, math.rad(200), 0),
		Color = Color3.fromRGB(120, 80, 45),
		Material = Enum.Material.Wood,
		Parent = folder,
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
		label.Text = "Training Ground"
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 236, 190)
		label.Parent = gui
	end
end

function TrainingGround.Start()
	local folder = Instance.new("Folder")
	folder.Name = "TrainingGround"
	folder.Parent = workspace

	local groundY = groundHeightAt(CENTER, folder)

	makePart({
		Name = "DirtPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 40, 40),
		CFrame = CFrame.new(CENTER + Vector3.new(0, groundY + 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(125, 96, 64),
		Material = Enum.Material.Ground,
		Parent = folder,
	})
	groundY += 0.3
	buildSign(folder, groundY)

	local template = loadDummyTemplate()
	for i = 1, DUMMY_COUNT do
		local dummy = createDummy(template, i)
		local x = (i - (DUMMY_COUNT + 1) / 2) * DUMMY_SPACING
		-- Face the spawn (toward -Z).
		local standing = CFrame.lookAt(CENTER + Vector3.new(x, groundY, 6), CENTER + Vector3.new(x, groundY, -100))
		dummy:PivotTo(standing)
		dummy.Parent = folder

		Damageable.Setup(dummy, {
			DisplayName = "Training Dummy",
			MaxHealth = DUMMY_HEALTH,
			Level = 1,
			BarHeight = DUMMY_HEIGHT + 1.5,
			HitHeight = DUMMY_HEIGHT * 0.58,
		})
		Damageable.OnDied(dummy, function(_, contributors)
			for player in contributors do
				if player.Parent then
					LevelingService.AddXP(player, DUMMY_XP)
					Remotes.Reward:FireClient(player, dummy:GetPivot().Position + Vector3.new(0, DUMMY_HEIGHT * 0.6, 0), DUMMY_XP, 0)
				end
			end
			tip(dummy, standing, true)
			task.wait(RESPAWN_DELAY)
			tip(dummy, standing, false)
			task.wait(0.5)
			Damageable.Reset(dummy)
		end)
	end
	if template then
		template:Destroy()
	end
end

return TrainingGround
