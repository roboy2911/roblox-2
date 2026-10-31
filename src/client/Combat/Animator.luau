-- Plays keyframed animations from PunchAnimations on R15 characters.
-- Each frame, after Roblox's own animations run, it adds the pose on top of
-- each joint's Transform. That way punches blend with walking and idling,
-- and no animation assets have to be uploaded.

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Images = require(ReplicatedStorage.Shared.Images)
local PunchAnimations = require(script.Parent.PunchAnimations)

type Animation = PunchAnimations.Animation
-- A joint we can pose: a Motor6D (classic rigs) or an AnimationConstraint
-- (Roblox's newer avatar joints). Both have a Transform property.
type Joint = Instance
type Values = { number } -- x, y, z (degrees), px, py, pz (studs)

local JOINTS = {
	"Root", "Waist", "Neck",
	"RightShoulder", "RightElbow", "RightWrist",
	"LeftShoulder", "LeftElbow", "LeftWrist",
	"RightHip", "RightKnee", "LeftHip", "LeftKnee",
}

local EASE: { [string]: (number) -> number } = {
	Linear = function(a)
		return a
	end,
	QuadOut = function(a)
		return 1 - (1 - a) * (1 - a)
	end,
	BackOut = function(a) -- overshoots a little, then settles: gives the snap
		local c1 = 1.70158
		return 1 + (c1 + 1) * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
	end,
	SineInOut = function(a)
		return -(math.cos(math.pi * a) - 1) / 2
	end,
}

local REST: Values = { 0, 0, 0, 0, 0, 0 }

type Playing = {
	Animation: Animation,
	Elapsed: number,
	PausedFor: number,
	StartPose: { [string]: Values }, -- where the previous animation left off
	Trail: Trail?,
}

type State = {
	Character: Model,
	Motors: { [string]: Joint },
	Current: { [string]: Values }, -- last pose applied per joint
	Base: { [Joint]: CFrame },
	Written: { [Joint]: CFrame },
	Playing: Playing?,
	Trails: { [string]: Trail },
}

local Animator = {}

local states: { [Model]: State } = {}
local warned: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local function isJoint(instance: Instance?): boolean
	return instance ~= nil and (instance:IsA("Motor6D") or instance:IsA("AnimationConstraint"))
end

-- Finds a joint by name. With the newer avatar joints there can be both a
-- Motor6D and an AnimationConstraint with the same name; the constraint is
-- the one that actually moves the limb, so prefer it.
local function findJoint(character: Model, name: string): Joint?
	local found = nil
	for _, descendant in character:GetDescendants() do
		if descendant.Name == name and isJoint(descendant) then
			if descendant:IsA("AnimationConstraint") then
				return descendant
			end
			found = found or descendant
		end
	end
	return found
end

local function getState(character: Model): State?
	local state = states[character]
	if state then
		return state
	end
	local motors = {}
	for _, name in JOINTS do
		local joint = findJoint(character, name)
		if joint then
			motors[name] = joint
		end
	end
	if not motors.Waist and not motors.RightShoulder then
		if not warned[character] then
			warned[character] = true
			warn("[Animator] No R15 joints found on " .. character.Name .. ", punches won't animate. Is the game set to R15 (Game Settings > Avatar)?")
		end
		return nil
	end
	state = {
		Character = character,
		Motors = motors,
		Current = {},
		Base = {},
		Written = {},
		Playing = nil,
		Trails = {},
	}
	states[character] = state
	character.Destroying:Connect(function()
		states[character] = nil
	end)
	return state
end

-- A white streak behind the fist, reused for every punch.
local function getTrail(state: State, handName: string): Trail?
	local existing = state.Trails[handName]
	if existing and existing.Parent then
		return existing
	end
	local hand = state.Character:FindFirstChild(handName)
	if not hand then
		return nil
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailTop"
	a0.Position = Vector3.new(0, 0.25, 0)
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailBottom"
	a1.Position = Vector3.new(0, -0.35, 0)
	a1.Parent = hand

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.MinLength = 0.05
	trail.FaceCamera = true
	trail.LightEmission = 0.7
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 214, 140))
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	trail.TextureMode = Enum.TextureMode.Stretch
	trail.Texture = Images.Get("FxTrail")
	trail.Enabled = false
	trail.Parent = hand
	state.Trails[handName] = trail
	return trail
end

-- Rotation order: z (raise sideways), then x (swing forward), then y (turn
-- around the vertical). So a shoulder raises the arm forward first and then
-- swings it across the body, instead of the y turn doing nothing.
local function toCFrame(v: Values): CFrame
	return CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0)
		* CFrame.Angles(0, math.rad(v[2] or 0), 0)
		* CFrame.Angles(math.rad(v[1] or 0), 0, 0)
		* CFrame.Angles(0, 0, math.rad(v[3] or 0))
end

local function mix(a: Values, b: Values, t: number): Values
	local out = table.create(6)
	for i = 1, 6 do
		local from = a[i] or 0
		out[i] = from + ((b[i] or 0) - from) * t
	end
	return out
end

-- The pose of one joint at a moment in the animation.
local function sample(playing: Playing, joint: string): Values
	local anim = playing.Animation
	local time = math.min(playing.Elapsed, anim.Length)
	local prevTime, prevPose = 0, playing.StartPose[joint] or REST
	for _, keyframe in anim.Keyframes do
		local pose = keyframe.Pose[joint] or REST
		if time <= keyframe.Time then
			local span = keyframe.Time - prevTime
			local alpha = if span > 0 then (time - prevTime) / span else 1
			return mix(prevPose, pose, (EASE[keyframe.Ease] or EASE.Linear)(alpha))
		end
		prevTime, prevPose = keyframe.Time, pose
	end
	return prevPose
end

-- Adds an offset to a joint without letting it build up frame after frame
-- (if no Roblox animation reset the joint since our last write).
local function apply(state: State, motor: any, offset: CFrame?)
	local base: CFrame = motor.Transform
	local written = state.Written[motor]
	if written and base == written then
		base = state.Base[motor]
	end
	if offset then
		local pose = base * offset
		motor.Transform = pose
		state.Base[motor] = base
		state.Written[motor] = pose
	else
		motor.Transform = base
		state.Base[motor] = nil
		state.Written[motor] = nil
	end
end

-- Like apply, but a failure prints once instead of breaking the loop.
local function safeApply(state: State, motor: any, offset: CFrame?)
	local ok, err = pcall(apply, state, motor, offset)
	if not ok and not warned[state.Character] then
		warned[state.Character] = true
		warn(("[Animator] Couldn't pose %s (%s): %s"):format(motor.Name, motor.ClassName, tostring(err)))
	end
end

local function step(_time: number, dt: number)
	for character, state in states do
		local playing = state.Playing
		if not playing then
			continue
		end
		if not character.Parent then
			states[character] = nil
			continue
		end

		if playing.PausedFor > 0 then
			playing.PausedFor -= dt -- hit-stop: hold the current pose
		else
			playing.Elapsed += dt
		end
		local finished = playing.Elapsed >= playing.Animation.Length

		local trailInfo = playing.Animation.Trail
		if playing.Trail and trailInfo then
			playing.Trail.Enabled = not finished
				and playing.Elapsed >= trailInfo.From
				and playing.Elapsed <= trailInfo.To
		end

		for name, motor in state.Motors do
			if finished then
				safeApply(state, motor, nil)
				state.Current[name] = nil
			else
				local values = sample(playing, name)
				state.Current[name] = values
				safeApply(state, motor, toCFrame(values))
			end
		end
		if finished then
			state.Playing = nil
		end
	end
end

-- Plays an animation by name. If one is already playing, the new one starts
-- from wherever the old one was, so there's no snapping.
function Animator.Play(character: Model, name: string)
	local animation = PunchAnimations[name]
	local state = animation and getState(character)
	if not state then
		return
	end
	if state.Playing and state.Playing.Trail then
		state.Playing.Trail.Enabled = false
	end
	local startPose = {}
	for joint, values in state.Current do
		startPose[joint] = values
	end
	local trail: Trail? = nil
	if animation.Trail and animation.Trail.Hand == "Weapon" then
		-- The trail along the held weapon's blade (made by the server).
		local weapon = character:FindFirstChild("EquippedWeapon")
		local found = weapon and weapon:FindFirstChild("WeaponTrail", true)
		if found and found:IsA("Trail") then
			trail = found
			found.FaceCamera = true
			found.LightEmission = 0.6
			found.TextureMode = Enum.TextureMode.Stretch
			found.Color = ColorSequence.new(Color3.fromRGB(235, 240, 255))
			found.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		end
	elseif animation.Trail then
		trail = getTrail(state, animation.Trail.Hand)
	end
	if trail and trail.Texture == "" then
		trail.Texture = Images.Get("FxTrail") -- may not have been ready earlier
	end
	state.Playing = {
		Animation = animation,
		Elapsed = 0,
		PausedFor = 0,
		StartPose = startPose,
		Trail = trail,
	}
end

-- Freezes the character's current pose for a moment, so hits feel heavy.
function Animator.HitStop(character: Model, seconds: number)
	local state = states[character]
	if state and state.Playing then
		state.Playing.PausedFor = math.max(state.Playing.PausedFor, seconds)
	end
end

function Animator.Start()
	RunService.Stepped:Connect(step)
end

return Animator
