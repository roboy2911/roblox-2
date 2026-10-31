-- Builds Greenvale at startup: hides the Baseplate, lays out the sea and
-- the islands (our own ground tiles), docks, and decorative trees. Also
-- tracks which island each player is on: you respawn on the last island
-- you visited (player attribute Island).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Config.Assets)
local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)
local World = require(ReplicatedStorage.Shared.Config.World)
local AssetService = require(script.Parent.AssetService)
local DataService = require(script.Parent.DataService)
local Props = require(script.Parent.Props)

local WorldService = {}

local folder: Folder

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

local function tile(target: BasePart, imageName: string, face: Enum.NormalId, studs: number, transparency: number?)
	local decalId = Assets.Images[imageName]
	local image = decalId and AssetService.ImageFromDecal(decalId)
	if not image then
		return nil
	end
	local texture = Instance.new("Texture")
	texture.Name = imageName
	texture.Texture = image
	texture.Face = face
	texture.StudsPerTileU = studs
	texture.StudsPerTileV = studs
	texture.Transparency = transparency or 0
	texture.Parent = target
	return texture
end

local function hideBaseplate()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanQuery = false
		baseplate.CanTouch = false
		for _, child in baseplate:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end
	end
end

local function buildSea()
	local sea = part({
		Name = "Sea",
		Size = Vector3.new(2048, 1, 2048),
		Position = World.SeaCenter + Vector3.new(0, World.WaterLevel - 0.5, 0),
		Color = Color3.fromRGB(40, 110, 150),
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
	})
	tile(sea, "TileWater", Enum.NormalId.Top, 30, 0.15)
	-- Shallow sea floor so you wade instead of sinking forever.
	part({
		Name = "SeaFloor",
		Size = Vector3.new(2048, 2, 2048),
		Position = World.SeaCenter + Vector3.new(0, World.WaterLevel - 5, 0),
		Transparency = 1,
		CanQuery = false,
		CanTouch = false,
	})
end

local function buildIsland(island)
	local diameter = island.Radius * 2
	-- Cylinders lie along X; turning them 90 degrees makes the flat end face up (the Right face).
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local beach = part({
		Name = island.Id .. "Beach",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(20, diameter + 26, diameter + 26),
		CFrame = CFrame.new(island.Center.X, -10.6, island.Center.Z) * upright,
		Color = Color3.fromRGB(215, 190, 135),
	})
	tile(beach, "TileSand", Enum.NormalId.Right, 14)
	local ground = part({
		Name = island.Id .. "Ground",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(20, diameter, diameter),
		CFrame = CFrame.new(island.Center.X, -10, island.Center.Z) * upright,
		Color = island.GroundColor,
	})
	tile(ground, island.Ground, Enum.NormalId.Right, 16)

	if island.Dock then
		local facing = island.Dock.Facing.Unit
		-- The dock starts at the shore and reaches out over the water.
		-- The model's posts reach 4.8 studs below the deck; this puts the deck just above ground.
		Props.Place("Dock", island.Dock.Position + facing * 6 + Vector3.new(0, -4.7, 0), facing, folder)
	end
end

-- Decorative trees and rocks, kept away from fighting areas, docks and spawns.
local function scatterTrees(island)
	if not island.Trees then
		return
	end
	local rng = Random.new(#island.Id * 97)
	local placed, tries = 0, 0
	while placed < island.Trees and tries < island.Trees * 20 do
		tries += 1
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = math.sqrt(rng:NextNumber()) * island.Radius * 0.92
		local spot = island.Center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local clear = (spot - island.Spawn).Magnitude > 22
			and (island.Dock == nil or (spot - island.Dock.Position).Magnitude > 22)
		for _, area in Enemies.SpawnAreas do
			if ((spot - area.Center) * Vector3.new(1, 0, 1)).Magnitude < area.Radius + 14 then
				clear = false
			end
		end
		if clear then
			local facing = Vector3.new(math.cos(angle * 3), 0, math.sin(angle * 3))
			if placed % 5 == 4 then
				Props.Place("Rock", spot, facing, folder, rng:NextNumber(0.8, 1.6))
			else
				Props.Place("Tree", spot, facing, folder, rng:NextNumber(1.0, 1.6))
			end
			placed += 1
		end
	end
end

local function respawnOnIsland(player: Player, character: Model)
	local profile = DataService.Get(player)
	local island = profile and World.IslandById(profile.Data.Island)
	if not island or island.Id == "Millbrook" then
		return -- Millbrook uses the place's normal spawn
	end
	task.wait(0.1)
	if character.Parent then
		character:PivotTo(CFrame.new(island.Spawn + Vector3.new(0, 4, 0)))
	end
end

function WorldService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Greenvale"
	folder.Parent = workspace

	hideBaseplate()
	buildSea()
	for _, island in World.Islands do
		buildIsland(island)
	end
	task.spawn(function()
		for _, island in World.Islands do
			scatterTrees(island)
		end
	end)

	DataService.OnLoaded(function(player, profile)
		player:SetAttribute("Island", profile.Data.Island)
		player.CharacterAdded:Connect(function(character)
			respawnOnIsland(player, character)
		end)
		if player.Character then
			task.spawn(respawnOnIsland, player, player.Character)
		end
	end)

	-- Remember the island each player is on.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local profile = DataService.Get(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local island = root and World.IslandAt(root.Position)
				if profile and island and profile.Data.Island ~= island.Id then
					profile.Data.Island = island.Id
					player:SetAttribute("Island", island.Id)
				end
			end
		end
	end)
end

return WorldService
