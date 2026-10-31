-- Gem moves on Z / X / C, plus the ability bar above the HUD.
--
-- Pressing a key checks (from what the server tells us) that you have a
-- gem, the level, the energy, and that the move is off cooldown. Then it
-- plays the cast animation right away and asks the server to cast.
--   Z  Fireball: flies toward your mouse
--   X  Flame Dash: dashes the way you're moving (or facing)
--   C  Fire Ring: blast around you

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombatFolder = script.Parent.Parent.Combat
local AbilityEffects = require(CombatFolder.AbilityEffects)
local Animator = require(CombatFolder.Animator)
local Movement = require(CombatFolder.Movement)

local player = Players.LocalPlayer

local KEYS = { "Z", "X", "C" }
local KEYCODES = { [Enum.KeyCode.Z] = "Z", [Enum.KeyCode.X] = "X", [Enum.KeyCode.C] = "C" }
local ANIMATIONS = { Fireball = "CastFireball", ["Flame Dash"] = "FlameDash", ["Fire Ring"] = "FireRing" }

local COLORS = {
	Panel = Color3.fromRGB(28, 22, 18),
	Border = Color3.fromRGB(196, 160, 82),
	Text = Color3.fromRGB(255, 244, 220),
	Muted = Color3.fromRGB(170, 155, 135),
	Energy = Color3.fromRGB(120, 180, 255),
}

local AbilityController = {}

local pending: { [string]: number } = {} -- stops double presses before the server answers

local function currentMove(key: string)
	local gem = Gems.List[player:GetAttribute("Gem") or ""]
	return gem and gem.Moves[key], gem
end

-- Where the mouse points in the world (or straight ahead on touch screens).
local function aimPoint(rootPart: BasePart): Vector3
	local camera = workspace.CurrentCamera
	if UserInputService.MouseEnabled then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character :: Instance }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		return if hit then hit.Position else ray.Origin + ray.Direction * 500
	end
	return rootPart.Position + rootPart.CFrame.LookVector * 60
end

local function canUse(key: string): (boolean, any)
	local move = currentMove(key)
	if not move then
		return false, nil
	end
	if (player:GetAttribute("Level") or 1) < move.Level then
		return false, move
	end
	local now = workspace:GetServerTimeNow()
	if now < (player:GetAttribute("CD_" .. key) or 0) or os.clock() < (pending[key] or 0) then
		return false, move
	end
	if (player:GetAttribute("Energy") or 0) < move.Energy then
		return false, move
	end
	return true, move
end

local function use(key: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return
	end
	local ok, move = canUse(key)
	if not ok then
		return
	end
	pending[key] = os.clock() + 0.4

	if move.Name == "Fireball" then
		local aim = aimPoint(root)
		Movement.Face(humanoid, root, aim - root.Position, (move.CastTime or 0.15) + 0.25)
		Remotes.UseAbility:FireServer(key, aim)
	elseif move.Name == "Flame Dash" then
		local direction = humanoid.MoveDirection * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.1 then
			direction = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		direction = direction.Unit
		Movement.Face(humanoid, root, direction, move.DashTime + 0.1)
		Remotes.UseAbility:FireServer(key, direction)
		Movement.Burst(root, direction, move.Distance / move.DashTime, move.DashTime)
	else
		Remotes.UseAbility:FireServer(key)
	end
	local animation = ANIMATIONS[move.Name]
	if animation then
		Animator.Play(character :: Model, animation)
	end
end

-- Ability bar ---------------------------------------------------------------

type Slot = { Frame: Frame, Name: TextLabel, Cost: TextLabel, Shade: Frame, Timer: TextLabel, Lock: TextLabel }

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextColor3 = COLORS.Text
	l.TextStrokeTransparency = 0.5
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function buildBar(): (Frame, TextLabel, { [string]: Slot })
	local gui = Instance.new("ScreenGui")
	gui.Name = "AbilityBar"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -146) -- above the HUD and its gold counter
	bar.Size = UDim2.fromOffset(3 * 78 + 2 * 8, 104)
	bar.BackgroundTransparency = 1
	bar.Visible = false
	bar.Parent = gui

	local title = label({ Size = UDim2.new(1, 0, 0, 20), Font = Enum.Font.Fantasy, TextSize = 20, TextColor3 = COLORS.Border, Parent = bar })

	local slots = {}
	for i, key in KEYS do
		local frame = Instance.new("TextButton")
		frame.Text = ""
		frame.AutoButtonColor = false
		frame.Position = UDim2.fromOffset((i - 1) * 86, 24)
		frame.Size = UDim2.fromOffset(78, 78)
		frame.BackgroundColor3 = COLORS.Panel
		frame.BackgroundTransparency = 0.15
		frame.Parent = bar
		corner(frame, 10)
		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.Border
		stroke.Thickness = 1.5
		stroke.Parent = frame
		frame.Activated:Connect(function()
			use(key)
		end)

		label({ Text = key, TextSize = 16, Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(20, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = COLORS.Border, Parent = frame })
		local cost = label({ TextSize = 12, Position = UDim2.new(1, -40, 0, 5), Size = UDim2.fromOffset(34, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = COLORS.Energy, Parent = frame })
		local name = label({ TextSize = 13, TextWrapped = true, Position = UDim2.new(0, 4, 1, -38), Size = UDim2.new(1, -8, 0, 34), Font = Enum.Font.GothamMedium, Parent = frame })

		local shade = Instance.new("Frame")
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.35
		shade.AnchorPoint = Vector2.new(0, 1)
		shade.Position = UDim2.fromScale(0, 1)
		shade.Size = UDim2.fromScale(1, 0)
		shade.ZIndex = 2
		shade.Parent = frame
		corner(shade, 10)
		local timer = label({ TextSize = 24, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = frame })
		local lock = label({ TextSize = 14, Size = UDim2.fromScale(1, 1), ZIndex = 3, TextColor3 = COLORS.Muted, BackgroundTransparency = 0.3, BackgroundColor3 = Color3.new(0, 0, 0), Parent = frame })
		corner(lock, 10)

		slots[key] = { Frame = frame :: any, Name = name, Cost = cost, Shade = shade, Timer = timer, Lock = lock }
	end
	return bar, title, slots
end

function AbilityController.Start()
	AbilityEffects.Start()
	local bar, title, slots = buildBar()

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local key = KEYCODES[input.KeyCode]
		if key then
			use(key)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local _, gem = currentMove("Z")
		bar.Visible = gem ~= nil
		if not gem then
			return
		end
		title.Text = gem.DisplayName
		local now = workspace:GetServerTimeNow()
		local level = player:GetAttribute("Level") or 1
		local energy = player:GetAttribute("Energy") or 0
		for _, key in KEYS do
			local slot = slots[key]
			local move = gem.Moves[key]
			slot.Frame.Visible = move ~= nil
			if not move then
				continue
			end
			slot.Name.Text = move.Name
			slot.Cost.Text = tostring(move.Energy)
			local locked = level < move.Level
			slot.Lock.Visible = locked
			slot.Lock.Text = ("Lv. %d"):format(move.Level)
			local left = (player:GetAttribute("CD_" .. key) or 0) - now
			if not locked and left > 0 then
				slot.Shade.Size = UDim2.fromScale(1, math.clamp(left / move.Cooldown, 0, 1))
				slot.Timer.Text = ("%.1f"):format(left)
			else
				slot.Shade.Size = UDim2.fromScale(1, 0)
				slot.Timer.Text = ""
			end
			slot.Cost.TextColor3 = if energy >= move.Energy then COLORS.Energy else Color3.fromRGB(230, 90, 80)
		end
	end)
end

return AbilityController
