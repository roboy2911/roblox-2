-- Keyframes for the Brawler punches (R15 characters).
--
-- Each pose lists joints as { x, y, z, px, py, pz }: rotation in degrees
-- around the joint, then an optional offset in studs. Joints not listed in a
-- keyframe are at rest. Every animation starts and ends at rest, so they
-- blend into the normal walk/idle animation.
--
-- Directions (with the character facing forward):
--   Shoulder/Hip  +x = swing forward, +y (right side) = across the body
--   Elbow         +x = bend        Knee  -x = bend
--   Waist/Root    +y = turn so the right shoulder comes forward, -x = lean forward
--   Root offset   py = up/down, pz = back(+)/forward(-)
--
-- Left-hand moves are made by mirroring right-hand ones.

export type JointPose = { number }
export type Keyframe = { Time: number, Ease: string, Pose: { [string]: JointPose } }
export type Animation = {
	Length: number,
	Keyframes: { Keyframe },
	Trail: { Hand: string, From: number, To: number }?,
}

local JabRight: Animation = {
	Length = 0.42,
	Trail = { Hand = "RightHand", From = 0.06, To = 0.2 },
	Keyframes = {
		{ -- wind up: twist back, fist chambered at the chin
			Time = 0.07,
			Ease = "QuadOut",
			Pose = {
				Root = { 0, -8, 0, 0, -0.15, 0.1 },
				Waist = { 5, -25, 0 },
				Neck = { 0, 18, 0 },
				RightShoulder = { 30, -10, 0 },
				RightElbow = { 115, 0, 0 },
				LeftShoulder = { 55, -20, 0 },
				LeftElbow = { 120, 0, 0 },
				RightHip = { -5, 0, 0 },
				RightKnee = { -10, 0, 0 },
				LeftHip = { 12, 0, 0 },
				LeftKnee = { -15, 0, 0 },
			},
		},
		{ -- strike: hips and shoulders snap through, arm fully extended
			Time = 0.13,
			Ease = "BackOut",
			Pose = {
				Root = { 0, 12, 0, 0, -0.12, -0.3 },
				Waist = { -10, 30, 0 },
				Neck = { 5, -30, 0 },
				RightShoulder = { 92, 16, 0 },
				RightElbow = { 4, 0, 0 },
				LeftShoulder = { 45, -25, 0 },
				LeftElbow = { 125, 0, 0 },
				RightHip = { -18, 0, 0 },
				RightKnee = { -8, 0, 0 },
				LeftHip = { 22, 0, 0 },
				LeftKnee = { -28, 0, 0 },
			},
		},
		{ -- hold the hit for a moment
			Time = 0.21,
			Ease = "Linear",
			Pose = {
				Root = { 0, 10, 0, 0, -0.1, -0.28 },
				Waist = { -8, 27, 0 },
				Neck = { 4, -26, 0 },
				RightShoulder = { 86, 14, 0 },
				RightElbow = { 10, 0, 0 },
				LeftShoulder = { 45, -25, 0 },
				LeftElbow = { 122, 0, 0 },
				RightHip = { -15, 0, 0 },
				RightKnee = { -8, 0, 0 },
				LeftHip = { 20, 0, 0 },
				LeftKnee = { -25, 0, 0 },
			},
		},
		{ Time = 0.42, Ease = "SineInOut", Pose = {} }, -- recover
	},
}

local UppercutRight: Animation = {
	Length = 0.66,
	Trail = { Hand = "RightHand", From = 0.13, To = 0.36 },
	Keyframes = {
		{ -- deep crouch, coil the body, fist dropped low
			Time = 0.14,
			Ease = "QuadOut",
			Pose = {
				Root = { 0, -15, 0, 0, -0.5, 0.2 },
				Waist = { -8, -40, 0 },
				Neck = { 5, 28, 0 },
				RightShoulder = { -25, -10, 12 },
				RightElbow = { 95, 0, 0 },
				LeftShoulder = { 60, -25, 0 },
				LeftElbow = { 118, 0, 0 },
				RightHip = { 32, 0, 0 },
				RightKnee = { -55, 0, 0 },
				LeftHip = { 38, 0, 0 },
				LeftKnee = { -58, 0, 0 },
			},
		},
		{ -- explode upward: legs drive, body rises, fist goes up through the target
			Time = 0.24,
			Ease = "BackOut",
			Pose = {
				Root = { 6, 15, 0, 0, 0.2, -0.6 },
				Waist = { 10, 38, 0 },
				Neck = { 12, -28, 0 },
				RightShoulder = { 158, 20, 0 },
				RightElbow = { 25, 0, 0 },
				LeftShoulder = { -25, 0, -10 },
				LeftElbow = { 45, 0, 0 },
				RightHip = { -22, 0, 0 },
				RightKnee = { -8, 0, 0 },
				LeftHip = { 28, 0, 0 },
				LeftKnee = { -18, 0, 0 },
			},
		},
		{ -- hang at the top
			Time = 0.38,
			Ease = "Linear",
			Pose = {
				Root = { 5, 13, 0, 0, 0.15, -0.55 },
				Waist = { 8, 34, 0 },
				Neck = { 10, -25, 0 },
				RightShoulder = { 152, 18, 0 },
				RightElbow = { 30, 0, 0 },
				LeftShoulder = { -20, 0, -8 },
				LeftElbow = { 45, 0, 0 },
				RightHip = { -18, 0, 0 },
				RightKnee = { -8, 0, 0 },
				LeftHip = { 25, 0, 0 },
				LeftKnee = { -18, 0, 0 },
			},
		},
		{ Time = 0.66, Ease = "SineInOut", Pose = {} }, -- recover
	},
}

-- Swaps left and right and flips the side-to-side directions.
local function mirror(animation: Animation): Animation
	local keyframes = {}
	for _, keyframe in animation.Keyframes do
		local pose = {}
		for joint, v in keyframe.Pose do
			local name = joint
			if string.find(joint, "^Right") then
				name = "Left" .. string.sub(joint, 6)
			elseif string.find(joint, "^Left") then
				name = "Right" .. string.sub(joint, 5)
			end
			pose[name] = { v[1], -v[2], -(v[3] or 0), -(v[4] or 0), v[5] or 0, v[6] or 0 }
		end
		table.insert(keyframes, { Time = keyframe.Time, Ease = keyframe.Ease, Pose = pose })
	end
	local trail = animation.Trail
	return {
		Length = animation.Length,
		Keyframes = keyframes,
		Trail = trail and {
			Hand = string.gsub(trail.Hand, "^Right", "Left"),
			From = trail.From,
			To = trail.To,
		},
	}
end

return {
	JabRight = JabRight,
	JabLeft = mirror(JabRight),
	UppercutRight = UppercutRight,
}
