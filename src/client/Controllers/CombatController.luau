-- Click to attack. Plays the punch right away (so it feels instant), tells
-- the server, and shows damage numbers when the server confirms a hit.
-- Punches are done by rotating the shoulder joints, so no animation assets
-- are needed yet.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local style = Combat.Styles[Combat.DefaultStyle]

local CombatController = {}

local comboIndex = 0
local lastSwing = 0
local readyAt = 0

local originalC0: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local activeTweens: { [Motor6D]: Tween } = setmetatable({}, { __mode = "k" }) :: any

local function shoulder(character: Model, side: string): (Motor6D?, boolean)
	local upperArm = character:FindFirstChild(side .. "UpperArm")
	if upperArm then
		return upperArm:FindFirstChild(side .. "Shoulder") :: Motor6D?, true
	end
	local torso = character:FindFirstChild("Torso")
	return torso and torso:FindFirstChild(side .. " Shoulder") :: Motor6D?, false
end

-- Punches with one arm: quick out, slower back.
local function playPunch(character: Model, index: number)
	local move = style.Combo[index]
	if not move then
		return
	end
	local motor, isR15 = shoulder(character, move.Arm)
	if not motor then
		return
	end
	if activeTweens[motor] then
		activeTweens[motor]:Cancel()
	end
	local base = originalC0[motor] or motor.C0
	originalC0[motor] = base

	local reach = math.rad(if move.Heavy then 110 else 90)
	local punch
	if isR15 then
		punch = base * CFrame.Angles(reach, 0, 0)
	else
		-- R6 shoulders rotate around their own Z axis; left and right are mirrored.
		punch = base * CFrame.Angles(0, 0, if move.Arm == "Right" then reach else -reach)
	end

	local out = TweenService:Create(motor, TweenInfo.new(if move.Heavy then 0.1 else 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = punch })
	local back = TweenService:Create(motor, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { C0 = base })
	activeTweens[motor] = out
	out.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			activeTweens[motor] = back
			back:Play()
		end
	end)
	out:Play()
end

local function tryAttack()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
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

	playPunch(character :: Model, comboIndex)
	Remotes.Attack:FireServer()
end

local function flash(target: Model)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = target
	TweenService:Create(highlight, TweenInfo.new(0.18), { FillTransparency = 1 }):Play()
	task.delay(0.2, function()
		highlight:Destroy()
	end)
end

local function damageNumber(target: Model, amount: number, big: boolean)
	local height = (target:GetAttribute("BarHeight") or 6) * 0.65
	local position = target:GetPivot().Position
		+ Vector3.new((math.random() - 0.5) * 2.5, height + math.random() * 0.8, (math.random() - 0.5) * 1.5)

	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 50)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = player:WaitForChild("PlayerGui")

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Fantasy
	text.Text = tostring(amount)
	text.TextSize = if big then 38 else 28
	text.TextColor3 = if big then Color3.fromRGB(255, 196, 64) else Color3.fromRGB(255, 255, 255)
	text.TextStrokeTransparency = 0.2
	text.Parent = gui

	TweenService:Create(anchor, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { WorldPosition = position + Vector3.new(0, 2, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.75, function()
		gui:Destroy()
		anchor:Destroy()
	end)
end

function CombatController.Start()
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
		if attacker ~= player and attacker.Character then
			playPunch(attacker.Character, index)
		end
	end)

	Remotes.HitConfirm.OnClientEvent:Connect(function(target: Model, amount: number, killed: boolean, heavy: boolean)
		if not target or not target.Parent then
			return
		end
		flash(target)
		damageNumber(target, amount, heavy or killed)
	end)

	player.CharacterAdded:Connect(function()
		comboIndex = 0
		readyAt = 0
	end)
end

return CombatController
