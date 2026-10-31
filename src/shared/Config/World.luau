-- Greenvale's islands. Each has a ground tile, a respawn point and a dock.
-- Ground tops are at Y = 0; the sea surface is at WaterLevel.

local World = {}

World.WaterLevel = -1
World.SeaCenter = Vector3.new(25, 0, -250)
World.BoatSpeed = 50
World.BoatTurnSpeed = 1.6 -- radians per second

World.Islands = {
	{
		Id = "Millbrook",
		Name = "Millbrook Village",
		Levels = "Lv. 1-30",
		Center = Vector3.new(25, 0, 10),
		Radius = 165,
		Ground = "TileGrass",
		GroundColor = Color3.fromRGB(80, 130, 55),
		Spawn = Vector3.new(0, 0, 0),
		Dock = { Position = Vector3.new(25, 0, -155), Facing = Vector3.new(0, 0, -1) },
	},
	{
		Id = "Whisperwood",
		Name = "Whisperwood Forest",
		Levels = "Lv. 30-90",
		Center = Vector3.new(25, 0, -555),
		Radius = 150,
		Ground = "TileForest",
		GroundColor = Color3.fromRGB(45, 85, 35),
		Spawn = Vector3.new(25, 0, -435),
		Dock = { Position = Vector3.new(25, 0, -405), Facing = Vector3.new(0, 0, 1) },
		Trees = 45, -- scattered for decoration
	},
}

function World.IslandById(id: string)
	for _, island in World.Islands do
		if island.Id == id then
			return island
		end
	end
	return nil
end

-- The island under a position (or nil when out at sea).
function World.IslandAt(position: Vector3)
	for _, island in World.Islands do
		local offset = (position - island.Center) * Vector3.new(1, 0, 1)
		if offset.Magnitude <= island.Radius + 8 then
			return island
		end
	end
	return nil
end

return World
