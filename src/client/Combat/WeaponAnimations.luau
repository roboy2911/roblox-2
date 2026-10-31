-- Keyframes for weapon swings and the Z/X moves of each slot.
-- Same format as PunchAnimations ({ x, y, z, px, py, pz } per joint).
-- The weapon sits in the right hand pointing forward-down; RightWrist
-- tilts it forward during swings.

return function(JabRight, mirror)
	local function kf(time: number, ease: string, pose)
		return { Time = time, Ease = ease, Pose = pose }
	end

	-- Stretches an animation in time (slower, heavier versions).
	local function scaled(animation, factor: number)
		local keyframes = {}
		for _, k in animation.Keyframes do
			table.insert(keyframes, kf(k.Time * factor, k.Ease, k.Pose))
		end
		local trail = animation.Trail
		return {
			Length = animation.Length * factor,
			Keyframes = keyframes,
			Trail = trail and { Hand = trail.Hand, From = trail.From * factor, To = trail.To * factor },
		}
	end

	-- Sword poses ----------------------------------------------------------
	local WOUND_RIGHT = {
		Root = { 0, -12, 0, 0, -0.1, 0.1 }, Waist = { 0, -35, 0 }, Neck = { 0, 20, 0 },
		RightShoulder = { 75, -55, 0 }, RightElbow = { 30, 0, 0 }, RightWrist = { -50, 0, 0 },
		LeftShoulder = { 20, 0, -15 }, LeftElbow = { 30, 0, 0 },
		RightHip = { 10, 0, 0 }, LeftHip = { -5, 0, 0 },
	}
	local THROUGH_LEFT = {
		Root = { 0, 14, 0, 0, -0.12, -0.3 }, Waist = { -5, 35, 0 }, Neck = { 0, -25, 0 },
		RightShoulder = { 80, 75, 0 }, RightElbow = { 8, 0, 0 }, RightWrist = { -55, 0, 0 },
		LeftShoulder = { 10, 0, -30 }, LeftElbow = { 20, 0, 0 },
		RightHip = { -15, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -25, 0, 0 },
	}
	local ACROSS_CHEST = {
		Root = { 0, 10, 0, 0, -0.1, 0.05 }, Waist = { 0, 30, 0 }, Neck = { 0, -15, 0 },
		RightShoulder = { 70, 85, 0 }, RightElbow = { 90, 0, 0 }, RightWrist = { -40, 0, 0 },
		LeftShoulder = { 15, 0, -20 },
	}
	local THROUGH_RIGHT = {
		Root = { 0, -14, 0, 0, -0.12, -0.3 }, Waist = { -5, -35, 0 }, Neck = { 0, 25, 0 },
		RightShoulder = { 80, -65, 0 }, RightElbow = { 8, 0, 0 }, RightWrist = { -55, 0, 0 },
		LeftShoulder = { 10, 0, -30 },
		RightHip = { -15, 0, 0 }, RightKnee = { -10, 0, 0 }, LeftHip = { 20, 0, 0 }, LeftKnee = { -25, 0, 0 },
	}
	local OVERHEAD = {
		Root = { 0, -5, 0, 0, -0.1, 0.15 }, Waist = { 10, -10, 0 }, Neck = { 10, 0, 0 },
		RightShoulder = { 165, 10, 0 }, RightElbow = { 40, 0, 0 }, RightWrist = { -30, 0, 0 },
		LeftShoulder = { 150, -15, 0 }, LeftElbow = { 50, 0, 0 },
	}
	local CHOP_DOWN = {
		Root = { -5, 5, 0, 0, -0.35, -0.45 }, Waist = { -18, 10, 0 }, Neck = { -5, 0, 0 },
		RightShoulder = { 55, 15, 0 }, RightElbow = { 5, 0, 0 }, RightWrist = { -70, 0, 0 },
		LeftShoulder = { 45, -20, 0 }, LeftElbow = { 30, 0, 0 },
		RightHip = { -25, 0, 0 }, RightKnee = { -15, 0, 0 }, LeftHip = { 35, 0, 0 }, LeftKnee = { -45, 0, 0 },
	}

	local SwordSlash1 = {
		Length = 0.48,
		Trail = { Hand = "Weapon", From = 0.08, To = 0.24 },
		Keyframes = { kf(0.1, "QuadOut", WOUND_RIGHT), kf(0.18, "BackOut", THROUGH_LEFT), kf(0.28, "Linear", THROUGH_LEFT), kf(0.48, "SineInOut", {}) },
	}
	local SwordSlash2 = {
		Length = 0.48,
		Trail = { Hand = "Weapon", From = 0.08, To = 0.24 },
		Keyframes = { kf(0.1, "QuadOut", ACROSS_CHEST), kf(0.18, "BackOut", THROUGH_RIGHT), kf(0.28, "Linear", THROUGH_RIGHT), kf(0.48, "SineInOut", {}) },
	}
	local SwordSlash3 = {
		Length = 0.62,
		Trail = { Hand = "Weapon", From = 0.16, To = 0.34 },
		Keyframes = { kf(0.18, "QuadOut", OVERHEAD), kf(0.26, "BackOut", CHOP_DOWN), kf(0.38, "Linear", CHOP_DOWN), kf(0.62, "SineInOut", {}) },
	}
	local SwordFlurry = {
		Length = 0.75,
		Trail = { Hand = "Weapon", From = 0.04, To = 0.48 },
		Keyframes = {
			kf(0.06, "QuadOut", WOUND_RIGHT), kf(0.12, "BackOut", THROUGH_LEFT),
			kf(0.2, "QuadOut", ACROSS_CHEST), kf(0.27, "BackOut", THROUGH_RIGHT),
			kf(0.35, "QuadOut", OVERHEAD), kf(0.42, "BackOut", CHOP_DOWN),
			kf(0.52, "Linear", CHOP_DOWN), kf(0.75, "SineInOut", {}),
		},
	}
	local THRUST = {
		Root = { -15, 20, 0, 0, -0.4, -0.3 }, Waist = { -10, 20, 0 }, Neck = { 10, -15, 0 },
		RightShoulder = { 90, 5, 0 }, RightElbow = { 0, 0, 0 }, RightWrist = { -75, 0, 0 },
		LeftShoulder = { -30, 0, -25 }, LeftElbow = { 20, 0, 0 },
		RightHip = { 45, 0, 0 }, RightKnee = { -50, 0, 0 }, LeftHip = { -30, 0, 0 }, LeftKnee = { -10, 0, 0 },
	}
	local SwordLunge = {
		Length = 0.5,
		Trail = { Hand = "Weapon", From = 0.06, To = 0.3 },
		Keyframes = {
			kf(0.08, "QuadOut", { Root = { 0, -10, 0, 0, -0.2, 0.1 }, Waist = { 0, -15, 0 }, RightShoulder = { 40, -10, 0 }, RightElbow = { 110, 0, 0 }, RightWrist = { -60, 0, 0 } }),
			kf(0.14, "BackOut", THRUST), kf(0.3, "Linear", THRUST), kf(0.5, "SineInOut", {}),
		},
	}

	-- Axe: the sword swings, slower and heavier, with a spin move ---------------
	local AxeSwing1 = scaled(SwordSlash1, 1.6)
	local AxeSwing2 = scaled(SwordSlash2, 1.6)
	local AxeSlam = scaled(SwordSlash3, 1.3)
	local AxeChop = scaled(SwordSlash3, 1.6)
	local SPIN_ARMS = {
		RightShoulder = { 85, -20, 0 }, RightElbow = { 10, 0, 0 }, RightWrist = { -60, 0, 0 },
		LeftShoulder = { 80, 20, 0 }, LeftElbow = { 30, 0, 0 }, Waist = { -8, 0, 0 },
		RightHip = { 15, 0, 0 }, LeftHip = { 15, 0, 0 }, RightKnee = { -25, 0, 0 }, LeftKnee = { -25, 0, 0 },
	}
	local function spinPose(degrees: number)
		local pose = table.clone(SPIN_ARMS)
		pose.Root = { 0, degrees, 0, 0, -0.3, 0 }
		return pose
	end
	local AxeSpin = {
		Length = 0.85,
		Trail = { Hand = "Weapon", From = 0.1, To = 0.66 },
		Keyframes = {
			kf(0.1, "QuadOut", spinPose(-40)),
			kf(0.28, "Linear", spinPose(-40 + 360)),
			kf(0.46, "Linear", spinPose(-40 + 720)),
			kf(0.64, "QuadOut", spinPose(-40 + 1080)),
			kf(0.85, "SineInOut", {}),
		},
	}

	-- Brawler moves ---------------------------------------------------------------
	local chamberR = JabRight.Keyframes[1].Pose
	local strikeR = JabRight.Keyframes[2].Pose
	local left = mirror({ Length = 1, Keyframes = { kf(0, "Linear", chamberR), kf(0, "Linear", strikeR) } })
	local chamberL, strikeL = left.Keyframes[1].Pose, left.Keyframes[2].Pose
	local PunchFlurry = {
		Length = 0.7,
		Keyframes = {
			kf(0.05, "QuadOut", chamberR), kf(0.1, "BackOut", strikeR),
			kf(0.145, "QuadOut", chamberL), kf(0.19, "BackOut", strikeL),
			kf(0.235, "QuadOut", chamberR), kf(0.28, "BackOut", strikeR),
			kf(0.325, "QuadOut", chamberL), kf(0.37, "BackOut", strikeL),
			kf(0.415, "QuadOut", chamberR), kf(0.46, "BackOut", strikeR),
			kf(0.52, "Linear", strikeR), kf(0.7, "SineInOut", {}),
		},
	}
	local CHARGE = {
		Root = { -15, -40, 0, 0, -0.25, 0 }, Waist = { -10, -20, 0 }, Neck = { 0, 40, 0 },
		RightShoulder = { 20, 60, 0 }, RightElbow = { 100, 0, 0 },
		LeftShoulder = { -30, 0, -20 }, LeftElbow = { 30, 0, 0 },
		RightHip = { 30, 0, 0 }, RightKnee = { -50, 0, 0 }, LeftHip = { -20, 0, 0 }, LeftKnee = { -20, 0, 0 },
	}
	local ShoulderCharge = {
		Length = 0.45,
		Keyframes = { kf(0.06, "QuadOut", CHARGE), kf(0.27, "Linear", CHARGE), kf(0.45, "SineInOut", {}) },
	}

	return {
		SwordSlash1 = SwordSlash1,
		SwordSlash2 = SwordSlash2,
		SwordSlash3 = SwordSlash3,
		SwordFlurry = SwordFlurry,
		SwordLunge = SwordLunge,
		AxeSwing1 = AxeSwing1,
		AxeSwing2 = AxeSwing2,
		AxeSlam = AxeSlam,
		AxeChop = AxeChop,
		AxeSpin = AxeSpin,
		PunchFlurry = PunchFlurry,
		ShoulderCharge = ShoulderCharge,
	}
end
