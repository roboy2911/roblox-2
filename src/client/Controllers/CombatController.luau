-- Click to attack. On click it:
--   1. turns you toward the nearest target in reach (aim assist)
--   2. tells the server, with the direction you're punching
--   3. plays the punch animation and lunges you forward
-- When the server says a hit landed, everyone sees the impact, and the
-- attacker also gets damage numbers, camera shake and a tiny freeze-frame.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatFolder = script.Parent.Parent.Combat
local Animator = require(CombatFolder.Animator)
local HitEffects = require(CombatFolder.HitEffects)
local Movement = require(CombatFolder.Movement)

local player = Players.LocalPlayer
local style = Combat.Styles[Combat.DefaultStyle]

local DAMAGEABLE_TAG = "Damageable"
local STOP_LUNGE_DISTANCE = 3.2 -- don't lunge into a target closer than this

local CombatController = {}

local comboIndex = 0
local lastSwing = 0
local readyAt = 0

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

-- Nearest living target within aim-assist range. Targets behind you count
-- as twice as far, so you don't spin around when something is in front.
local function findAimTarget(rootPart: BasePart): (Model?, number)
	local best, bestScore, bestDistance = nil, math.huge, math.huge
	local look = flat(rootPart.CFrame.LookVector)
	for _, model in CollectionService:GetTagged(DAMAGEABLE_TAG) do
		if not model:IsA("Model") or model:GetAttribute("Dead") or not model:IsDescendantOf(workspace) then
			continue
		end
		local offset = flat(model:GetPivot().Position - rootPart.Position)
		local distance = offset.Magnitude
		if distance > style.AimAssistRange then
			continue
		end
		local inFront = distance < 0.5 or look:Dot(offset.Unit) > -0.2
		local score = if inFront then distance else distance * 2
		if score < bestScore then
			best, bestScore, bestDistance = model, score, distance
		end
	end
	return best, bestDistance
end

local function tryAttack()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return
	end
	local now = os.clock()
	if now < readyAt then
		return
	end
	if now - lastSwing > style.ComboResetTime or comboIndex >= #style.Combo then
		comboIndex = 0
	end
	comboIndex += 1
	lastSwing = now
	readyAt = now + (if comboIndex == #style.Combo then style.ComboEndCooldown else style.SwingCooldown)
	local move = style.Combo[comboIndex]

	local direction = flat(rootPart.CFrame.LookVector).Unit
	local target, distance = findAimTarget(rootPart)
	if target and distance > 0.5 then
		direction = flat(target:GetPivot().Position - rootPart.Position).Unit
	end
	Movement.Face(humanoid, rootPart, direction, move.HitDelay + 0.2)

	-- Tell the server first, so a visual glitch can never block the attack.
	Remotes.Attack:FireServer(direction)

	Animator.Play(character :: Model, move.Animation)

	local lungeTime = move.LungeTime
	if target then
		local room = distance - STOP_LUNGE_DISTANCE
		lungeTime = math.clamp(room / move.LungeSpeed, 0, lungeTime)
	end
	Movement.Burst(rootPart, direction, move.LungeSpeed, lungeTime)
end

local function onHit(attacker: Player, target: Model, amount: number, killed: boolean, heavy: boolean)
	if not target or not target.Parent then
		return
	end
	local attackerRoot = attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local from = if attackerRoot then attackerRoot.Position else target:GetPivot().Position - Vector3.zAxis
	local position, direction = HitEffects.HitPoint(target, from)

	HitEffects.Impact(position, direction, heavy or killed)
	HitEffects.Flash(target)
	if not killed then
		HitEffects.Wobble(target, direction, heavy)
	end

	if attacker == player then
		HitEffects.DamageNumber(position, amount, heavy or killed)
		HitEffects.Shake(if heavy or killed then 1.6 else 0.6, if heavy then 0.3 else 0.15)
		if player.Character then
			Animator.HitStop(player.Character, if heavy then 0.09 else 0.05)
		end
	elseif attacker.Character then
		Animator.HitStop(attacker.Character, if heavy then 0.09 else 0.05)
	end
end

function CombatController.Start()
	Animator.Start()
	HitEffects.Start()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			tryAttack()
		end
	end)

	-- Other players' punches.
	Remotes.Swing.OnClientEvent:Connect(function(attacker: Player, index: number)
		local move = style.Combo[index]
		if attacker ~= player and attacker.Character and move then
			Animator.Play(attacker.Character, move.Animation)
		end
	end)

	Remotes.HitEffect.OnClientEvent:Connect(onHit)

	player.CharacterAdded:Connect(function()
		comboIndex = 0
		readyAt = 0
	end)
end

return CombatController
