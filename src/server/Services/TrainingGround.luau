-- Builds the training ground at game start: a dirt pad, a sign and a row of
-- training dummies, all using our textured models. If the dummy model can't
-- be loaded, a simple stand-in is built from blocks so testing still works.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AssetService = require(script.Parent.AssetService)
local Damageable = require(script.Parent.Damageable)
local LevelingService = require(script.Parent.LevelingService)
local Props = require(script.Parent.Props)

local CENTER = Vector3.new(0, 0, 40) -- training ground spot, away from spawn
local PAD_RADIUS = 20
local DUMMY_COUNT = 3
local DUMMY_SPACING = 9
local DUMMY_HEIGHT = 6
local DUMMY_HEALTH = 300
local DUMMY_XP = 40
local RESPAWN_DELAY = 3

local TrainingGround = {}

local function block(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = model
end

-- Plain stand-in dummy, only used if the model can't be loaded.
local function fallbackDummy(): Model
	local model = Instance.new("Model")
	local wood, straw, burlap = Color3.fromRGB(92, 58, 32), Color3.fromRGB(204, 173, 97), Color3.fromRGB(158, 128, 87)
	block(model, "Post", Vector3.new(0.4, 5, 0.4), CFrame.new(0, 2.5, 0), wood)
	block(model, "Feet", Vector3.new(2.2, 0.25, 0.35), CFrame.new(0, 0.125, 0), wood)
	block(model, "Feet2", Vector3.new(0.35, 0.25, 2.2), CFrame.new(0, 0.125, 0), wood)
	block(model, "Arms", Vector3.new(3.4, 0.3, 0.3), CFrame.new(0, 4.1, 0), wood)
	block(model, "Body", Vector3.new(1.6, 2.2, 1.6), CFrame.new(0, 3.3, 0), straw)
	block(model, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 5.15, 0), burlap)
	model.WorldPivot = CFrame.new()
	return model
end

local function createDummy(index: number): Model
	local model = AssetService.Model("TrainingDummy") or fallbackDummy()
	model.Name = "Training Dummy"

	-- Scale to a fixed height, then add an invisible root at the base.
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * DUMMY_HEIGHT / size.Y)
	local boxCFrame, boxSize = model:GetBoundingBox()
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Anchored = true
	root.Size = Vector3.new(1, 1, 1)
	root.CFrame = CFrame.new(boxCFrame.Position - Vector3.new(0, boxSize.Y / 2, 0))
	root.Transparency = 1
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
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

function TrainingGround.Start()
	local folder = Instance.new("Folder")
	folder.Name = "TrainingGround"
	folder.Parent = workspace

	local groundY = Props.GroundY(CENTER)
	Props.Place("DirtPad", Vector3.new(CENTER.X, groundY - 0.1, CENTER.Z), nil, folder, PAD_RADIUS / 20)
	groundY += 0.2
	Props.Sign("Training Ground", CENTER + Vector3.new(-16, groundY, -10), Vector3.new(0.3, 0, -1), folder)
	Props.Place("HayBale", CENTER + Vector3.new(15, groundY, -6), Vector3.new(1, 0, 0.4), folder)
	Props.Place("Barrel", CENTER + Vector3.new(16.5, groundY, -2), nil, folder)

	for i = 1, DUMMY_COUNT do
		local dummy = createDummy(i)
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
end

return TrainingGround
