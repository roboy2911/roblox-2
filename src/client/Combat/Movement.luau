-- Moves the local player's character for attacks and abilities: turning
-- to face a direction for a moment, and short bursts of speed.
-- Shared by punches and gem moves so they don't fight over facing.

local Movement = {}

local facingToken = 0

-- Faces a direction and keeps facing it for `hold` seconds, even while walking.
function Movement.Face(humanoid: Humanoid, rootPart: BasePart, direction: Vector3, hold: number)
	local flat = direction * Vector3.new(1, 0, 1)
	if flat.Magnitude < 0.01 then
		return
	end
	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat.Unit)
	facingToken += 1
	local token = facingToken
	humanoid.AutoRotate = false
	task.delay(hold, function()
		if token == facingToken and humanoid.Parent then
			humanoid.AutoRotate = true
		end
	end)
end

-- A burst of speed along the ground in `direction` for `seconds`.
function Movement.Burst(rootPart: BasePart, direction: Vector3, speed: number, seconds: number)
	if seconds <= 0 then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "BurstAttachment"
	attachment.Parent = rootPart
	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	velocity.LineDirection = direction.Unit
	velocity.LineVelocity = speed
	velocity.MaxForce = 80000
	velocity.Parent = rootPart
	task.delay(seconds, function()
		velocity:Destroy()
		attachment:Destroy()
	end)
end

return Movement
