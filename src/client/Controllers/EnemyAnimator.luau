-- Animates enemies on each player's screen. Legs walk in step with how
-- fast the enemy moves. Before attacking there's a clear wind-up (the
-- warning to dodge):
--   Rats: tail sways, head sniffs; the head rears back, then snaps forward.
--   Bandits: arms swing; the sword goes up overhead, then slashes down.
-- Works with the joints EnemyRig adds (a Motor6D named "Joint" in each part).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ENEMY_TAG = "Enemy"
local MAX_DISTANCE = 150 -- don't bother animating enemies far away

local EnemyAnimator = {}

type Rig = {
	Model: Model,
	Root: BasePart,
	Joints: { [string]: Motor6D },
	Biped: boolean,
	Phase: number,
	Seed: number,
}

local rigs: { [Model]: Rig } = {}

local function add(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart", 5)
	if not root or not model.Parent then
		return
	end
	local joints = {}
	for _, part in model:GetChildren() do
		local joint = part:FindFirstChild("Joint")
		if joint and joint:IsA("Motor6D") then
			joints[part.Name] = joint
		end
	end
	rigs[model] = {
		Model = model,
		Root = root :: BasePart,
		Joints = joints,
		Biped = model:GetAttribute("Rig") == "Biped" or joints.LegL ~= nil,
		Phase = 0,
		Seed = math.random() * 100,
	}
end

local function set(rig: Rig, name: string, cframe: CFrame)
	local joint = rig.Joints[name]
	if joint then
		joint.Transform = cframe
	end
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

-- How far into the bite we are, as poses for the head and body.
local function biteOffsets(model: Model, serverNow: number): (CFrame, CFrame)
	local start = model:GetAttribute("AttackStart") or 0
	local windup = model:GetAttribute("AttackWindup") or 0.4
	local t = serverNow - start
	if start <= 0 or t < 0 or t > windup + 0.45 then
		return CFrame.identity, CFrame.identity
	end
	local rear, lunge
	if t < windup then
		-- Rear back: nose up, head pulled back, front of body lifts.
		local a = smooth(t / windup)
		rear, lunge = a, 0
	elseif t < windup + 0.1 then
		-- Snap forward and down.
		local a = (t - windup) / 0.1
		rear, lunge = 1 - a, a
	else
		local a = smooth((t - windup - 0.1) / 0.35)
		rear, lunge = 0, 1 - a
	end
	local head = CFrame.new(0, 0.15 * rear - 0.1 * lunge, 0.3 * rear - 0.7 * lunge)
		* CFrame.Angles(math.rad(40 * rear - 30 * lunge), 0, 0)
	local body = CFrame.Angles(math.rad(12 * rear - 6 * lunge), 0, 0)
	return head, body
end

-- Bandit sword attack: raise overhead, slash down, recover.
-- Returns sword-arm angle, torso twist and torso lean (degrees).
local function slashPose(model: Model, serverNow: number): (number, number, number)
	local start = model:GetAttribute("AttackStart") or 0
	local windup = model:GetAttribute("AttackWindup") or 0.5
	local t = serverNow - start
	if start <= 0 or t < 0 or t > windup + 0.55 then
		return 0, 0, 0
	end
	if t < windup then
		local a = smooth(t / windup)
		return 150 * a, -22 * a, 8 * a
	elseif t < windup + 0.12 then
		local b = (t - windup) / 0.12
		return 150 - 130 * b, -22 + 44 * b, 8 - 18 * b
	end
	local c = 1 - smooth((t - windup - 0.12) / 0.43)
	return 20 * c, 22 * c, -10 * c
end

local function animateBiped(rig: Rig, model: Model, amount: number, t: number, serverNow: number)
	local swing = math.sin(rig.Phase) * math.rad(35) * amount
	set(rig, "LegL", CFrame.Angles(swing, 0, 0))
	set(rig, "LegR", CFrame.Angles(-swing, 0, 0))
	set(rig, "ArmL", CFrame.Angles(-swing * 0.8, 0, math.rad(-4)))

	local arm, twist, lean = slashPose(model, serverNow)
	set(rig, "ArmR", CFrame.Angles(math.rad(arm) + swing * 0.3, 0, math.rad(4)))

	local bob = math.abs(math.sin(rig.Phase)) * 0.1 * amount + math.sin(t * 2) * 0.02
	set(rig, "Torso", CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(lean), math.rad(twist), 0))

	local look = (1 - amount) * math.sin(t * 0.7) * math.rad(20)
	set(rig, "Head", CFrame.Angles(0, look - math.rad(twist) * 0.5, 0))
end

local function step(_time: number, dt: number)
	local camera = workspace.CurrentCamera
	local serverNow = workspace:GetServerTimeNow()
	local clock = os.clock()
	for model, rig in rigs do
		if not model.Parent then
			rigs[model] = nil
			continue
		end
		if model:GetAttribute("Dead") then
			continue
		end
		if camera and (rig.Root.Position - camera.CFrame.Position).Magnitude > MAX_DISTANCE then
			continue
		end

		local speed = (rig.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local amount = math.clamp(speed / 12, 0, 1)
		local t = clock + rig.Seed

		if rig.Biped then
			rig.Phase += dt * speed * 0.75
			animateBiped(rig, model, amount, t, serverNow)
			continue
		end
		rig.Phase += dt * (4 + speed * 1.1)

		-- Legs: diagonal pairs move together, like a real trot.
		local swing = math.sin(rig.Phase) * math.rad(45) * amount
		set(rig, "LegFL", CFrame.Angles(swing, 0, 0))
		set(rig, "LegBR", CFrame.Angles(swing, 0, 0))
		set(rig, "LegFR", CFrame.Angles(-swing, 0, 0))
		set(rig, "LegBL", CFrame.Angles(-swing, 0, 0))

		local headBite, bodyBite = biteOffsets(model, serverNow)

		-- Body bobs when running, breathes when still.
		local bob = math.abs(math.sin(rig.Phase)) * 0.12 * amount + math.sin(t * 3) * 0.02
		set(rig, "Body", CFrame.new(0, bob, 0) * bodyBite)

		-- Head sniffs around when idle.
		local sniff = (1 - amount) * math.sin(t * 2.4) * math.rad(8)
		local look = (1 - amount) * math.sin(t * 0.9) * math.rad(15)
		set(rig, "Head", CFrame.new(0, bob, 0) * headBite * CFrame.Angles(sniff, look, 0))

		-- Tail sways, faster when running.
		local wag = math.sin(t * (5 + amount * 6)) * math.rad(18 + 14 * amount)
		set(rig, "Tail", CFrame.Angles(math.sin(t * 2.5) * math.rad(6), wag, 0))
	end
end

function EnemyAnimator.Start()
	CollectionService:GetInstanceAddedSignal(ENEMY_TAG):Connect(function(model)
		task.spawn(add, model)
	end)
	CollectionService:GetInstanceRemovedSignal(ENEMY_TAG):Connect(function(model)
		rigs[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		task.spawn(add, model)
	end
	RunService.Stepped:Connect(step)
end

return EnemyAnimator
