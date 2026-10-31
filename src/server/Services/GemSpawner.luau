-- Plants the trees around Millbrook and, once an hour, leaves a gem under
-- one of them (one per server). The first one shows up 2 minutes after the
-- server starts. Hold E to eat it; it replaces whatever gem you had.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AssetService = require(script.Parent.AssetService)
local GemService = require(script.Parent.GemService)
local Props = require(script.Parent.Props)

local PICKUP_TAG = "GemPickup"
local GEM_HEIGHT = 1.6

local GemSpawner = {}

local treeSpots: { Vector3 } = {}
local current: Model? = nil
local folder: Folder

local function gemModel(gemId: string): Model
	local gem = Gems.List[gemId]
	local model = AssetService.Model(gem.Model)
	if not model then
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Name = "Gem"
		part.Size = Vector3.new(0.8, 1.3, 0.8)
		part.CFrame = CFrame.new(0, 0.65, 0)
		part.Color = gem.Color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.Parent = model
		model.WorldPivot = CFrame.new()
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * GEM_HEIGHT / size.Y)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end
	return model
end

-- Leaves a gem under a random tree. Returns false if one is already out.
function GemSpawner.SpawnGem(gemId: string?): boolean
	if current and current.Parent then
		return false
	end
	local list = Gems.TreeSpawn.Gems
	local id = gemId or list[math.random(1, #list)]
	local gem = Gems.List[id]
	if not gem or #treeSpots == 0 then
		return false
	end

	local tree = treeSpots[math.random(1, #treeSpots)]
	local angle = math.random() * math.pi * 2
	local spot = tree + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 3.2
	local y = Props.GroundY(spot, { folder })

	local model = gemModel(id)
	model.Name = gem.DisplayName
	model:PivotTo(CFrame.new(spot.X, y + 0.4, spot.Z))
	model:SetAttribute("GemId", id)

	-- Our own light, not a texture: makes it easy to spot at night or in shade.
	local core = model:FindFirstChildWhichIsA("BasePart")
	if core then
		local light = Instance.new("PointLight")
		light.Color = gem.Color
		light.Brightness = 2
		light.Range = 12
		light.Parent = core

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Eat"
		prompt.ObjectText = gem.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.6
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = core
		prompt.Triggered:Connect(function(player)
			if model.Parent == nil then
				return
			end
			model:Destroy()
			current = nil
			GemService.SetGem(player, id)
			Remotes.Notify:FireClient(player, ("You ate the %s! Press Z to use it."):format(gem.DisplayName))
		end)
	end

	model.Parent = folder
	CollectionService:AddTag(model, PICKUP_TAG)
	current = model
	for _, player in Players:GetPlayers() do
		Remotes.Notify:FireClient(player, ("A %s appeared under a tree near Millbrook!"):format(gem.DisplayName))
	end

	task.delay(Gems.TreeSpawn.Lifetime, function()
		if current == model then
			model:Destroy()
			current = nil
		end
	end)
	return true
end

function GemSpawner.Start()
	folder = Instance.new("Folder")
	folder.Name = "Trees"
	folder.Parent = workspace

	local rng = Random.new(11)
	for _, spot in Gems.Trees do
		local y = Props.GroundY(spot)
		local position = Vector3.new(spot.X, y, spot.Z)
		local facing = Vector3.new(math.cos(rng:NextNumber(0, 6.28)), 0, math.sin(rng:NextNumber(0, 6.28)))
		Props.Place("Tree", position, facing, folder, rng:NextNumber(0.9, 1.25))
		table.insert(treeSpots, position)
	end

	task.spawn(function()
		task.wait(Gems.TreeSpawn.FirstSpawnDelay)
		while true do
			GemSpawner.SpawnGem()
			task.wait(Gems.TreeSpawn.Interval)
		end
	end)
end

return GemSpawner
