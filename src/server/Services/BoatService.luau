-- Rowboats. At each island's dock, press E to get your own rowboat (one at
-- a time). Sit in it and steer with WASD; the driver's client moves it
-- (see BoatController). Boats nobody uses for 2 minutes disappear.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = require(ReplicatedStorage.Shared.Config.World)
local AssetService = require(script.Parent.AssetService)

local BOAT_TAG = "Boat"
local IDLE_LIFETIME = 120

local BoatService = {}

local boats: { [Player]: Model } = {}
local folder: Folder

local function hullModel(): Model
	local model = AssetService.Model("Rowboat")
	if not model then
		model = Instance.new("Model")
		local hull = Instance.new("Part")
		hull.Name = "Boat"
		hull.Size = Vector3.new(3.2, 1, 8.4)
		hull.CFrame = CFrame.new(0, 0.5, 0)
		hull.Color = Color3.fromRGB(130, 85, 45)
		hull.Material = Enum.Material.SmoothPlastic
		hull.Parent = model
		model.WorldPivot = CFrame.new()
	end
	return model
end

local function spawnBoat(player: Player, island)
	local old = boats[player]
	if old then
		old:Destroy()
	end
	local facing = island.Dock.Facing.Unit
	local side = facing:Cross(Vector3.yAxis)
	local spot = island.Dock.Position + facing * 14 + side * 7

	local model = hullModel()
	model.Name = player.Name .. "'s Rowboat"
	local hull = model:FindFirstChildWhichIsA("BasePart") :: BasePart
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			if p ~= hull then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hull
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end
	local _, size = model:GetBoundingBox()
	model:PivotTo(CFrame.lookAt(spot, spot + facing) + Vector3.new(0, World.WaterLevel - size.Y * 0.4, 0))

	-- Seat on the middle bench.
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(1.6, 0.4, 1.6)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.MaxSpeed = 0 -- we drive it ourselves
	seat.Torque = 0
	seat.CFrame = hull.CFrame * CFrame.new(0, 0.1, 0)
	seat.Parent = model
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = hull
	seatWeld.Part1 = seat
	seatWeld.Parent = seat

	-- Keeps the boat at water height and moves it; the driver sets these.
	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = hull
	local velocity = Instance.new("LinearVelocity")
	velocity.Name = "Move"
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = 1e6
	velocity.VectorVelocity = Vector3.zero
	velocity.Parent = hull
	local align = Instance.new("AlignOrientation")
	align.Name = "Upright"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 1e7
	align.Responsiveness = 25
	align.CFrame = CFrame.lookAt(Vector3.zero, facing)
	align.Parent = hull

	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("WaterY", hull.Position.Y)
	model:SetAttribute("LastUsed", os.clock())
	model.PrimaryPart = hull
	model.Parent = folder
	hull:SetNetworkOwner(nil)
	CollectionService:AddTag(model, BOAT_TAG)
	boats[player] = model

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local rider = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		model:SetAttribute("LastUsed", os.clock())
		if rider then
			hull:SetNetworkOwner(rider) -- the driver's client steers smoothly
		else
			velocity.VectorVelocity = Vector3.zero
			if hull:IsDescendantOf(workspace) then
				hull:SetNetworkOwner(nil)
			end
		end
	end)
end

function BoatService.Start()
	folder = Instance.new("Folder")
	folder.Name = "Boats"
	folder.Parent = workspace

	for _, island in World.Islands do
		if island.Dock then
			-- Prompt at the end of the dock.
			local facing = island.Dock.Facing.Unit
			local post = Instance.new("Part")
			post.Name = "BoatPrompt"
			post.Size = Vector3.new(2, 4, 2)
			post.Transparency = 1
			post.Anchored = true
			post.CanCollide = false
			post.CanQuery = false
			post.Position = island.Dock.Position + facing * 14 + Vector3.new(0, 2, 0)
			post.Parent = folder
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Get Rowboat"
			prompt.ObjectText = "Dock"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = post
			prompt.Triggered:Connect(function(player)
				spawnBoat(player, island)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		local boat = boats[player]
		if boat then
			boat:Destroy()
			boats[player] = nil
		end
	end)

	-- Hold empty boats at water height; remove ones nobody has used for a while.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, boat in boats do
				local hull = boat.PrimaryPart
				local seat = boat:FindFirstChild("Seat") :: VehicleSeat?
				if not hull or not boat.Parent then
					boats[player] = nil
					continue
				end
				if seat and seat.Occupant then
					boat:SetAttribute("LastUsed", os.clock())
				else
					local move = hull:FindFirstChild("Move") :: LinearVelocity?
					if move then
						local dy = (boat:GetAttribute("WaterY") or hull.Position.Y) - hull.Position.Y
						move.VectorVelocity = Vector3.new(0, dy * 4, 0)
					end
					if os.clock() - (boat:GetAttribute("LastUsed") or 0) > IDLE_LIFETIME then
						boat:Destroy()
						boats[player] = nil
					end
				end
			end
		end
	end)
end

return BoatService
