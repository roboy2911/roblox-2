-- Steers your rowboat while you sit in it: W/S forward and back, A/D turn.
-- Your client owns the boat's physics while you drive, so it sets the
-- boat's movement directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local World = require(ReplicatedStorage.Shared.Config.World)

local player = Players.LocalPlayer

local BoatController = {}

local yaw: number? = nil

function BoatController.Start()
	RunService.Heartbeat:Connect(function(dt)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and humanoid.SeatPart
		local boat = seat and seat:IsA("VehicleSeat") and seat.Parent
		if not boat or not CollectionService:HasTag(boat, "Boat") then
			yaw = nil
			return
		end
		local hull = (boat :: Model).PrimaryPart
		local move = hull and hull:FindFirstChild("Move") :: LinearVelocity?
		local align = hull and hull:FindFirstChild("Upright") :: AlignOrientation?
		if not hull or not move or not align then
			return
		end
		local vehicleSeat = seat :: VehicleSeat
		if not yaw then
			local look = hull.CFrame.LookVector
			yaw = math.atan2(-look.X, -look.Z)
		end
		yaw -= vehicleSeat.SteerFloat * World.BoatTurnSpeed * dt
		local heading = CFrame.Angles(0, yaw :: number, 0)
		align.CFrame = heading
		local forward = heading.LookVector
		local dy = ((boat :: Model):GetAttribute("WaterY") or hull.Position.Y) - hull.Position.Y
		move.VectorVelocity = forward * vehicleSeat.ThrottleFloat * World.BoatSpeed + Vector3.new(0, dy * 4, 0)
	end)
end

return BoatController
