-- Bottom-of-screen HUD: HP bar, level and XP bar, gold, plus level-up and
-- notice popups. Reads the attributes LevelingService puts on the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(28, 22, 18),
	Border = Color3.fromRGB(196, 160, 82),
	Text = Color3.fromRGB(255, 244, 220),
	Health = Color3.fromRGB(196, 52, 52),
	Energy = Color3.fromRGB(70, 140, 230),
	XP = Color3.fromRGB(232, 186, 64),
	BarBack = Color3.fromRGB(55, 45, 38),
}

local HUD = {}

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
	l.TextStrokeTransparency = 0.6
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

-- A bar with a fill and centered text. Returns a function to update it.
local function bar(parent: Instance, position: UDim2, size: UDim2, color: Color3)
	local back = Instance.new("Frame")
	back.Position = position
	back.Size = size
	back.BackgroundColor3 = COLORS.BarBack
	back.BorderSizePixel = 0
	back.Parent = parent
	corner(back, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Thickness = 1.5
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner(fill, 6)

	local text = label({ Size = UDim2.fromScale(1, 1), TextSize = 14, ZIndex = 2, Parent = back })

	return function(current: number, max: number, caption: string)
		local ratio = if max > 0 then math.clamp(current / max, 0, 1) else 1
		TweenService:Create(fill, TweenInfo.new(0.2), { Size = UDim2.fromScale(ratio, 1) }):Play()
		text.Text = caption
	end
end

local function popup(gui: ScreenGui, text: string, color: Color3, size: number)
	local l = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(600, 60),
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Font = Enum.Font.Fantasy,
		TextStrokeTransparency = 0.2,
		Parent = gui,
	})
	TweenService:Create(l, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.fromScale(0.5, 0.24),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(1.7, function()
		l:Destroy()
	end)
end

function HUD.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "StatusPanel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -16)
	panel.Size = UDim2.new(0.9, 0, 0, 96)
	panel.BackgroundColor3 = COLORS.Panel
	panel.BackgroundTransparency = 0.25
	panel.Parent = gui
	corner(panel, 10)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(420, 96)
	sizeLimit.Parent = panel

	local levelBadge = Instance.new("Frame")
	levelBadge.Position = UDim2.fromOffset(8, 17)
	levelBadge.Size = UDim2.fromOffset(62, 62)
	levelBadge.BackgroundColor3 = COLORS.Border
	levelBadge.Parent = panel
	corner(levelBadge, 31)
	local levelText = label({ Size = UDim2.fromScale(1, 0.62), Position = UDim2.fromScale(0, 0.2), TextScaled = true, Font = Enum.Font.Fantasy, TextColor3 = COLORS.Panel, TextStrokeTransparency = 1, Parent = levelBadge })
	label({ Size = UDim2.fromScale(1, 0.25), Position = UDim2.fromScale(0, 0.05), Text = "LV", TextSize = 11, TextColor3 = COLORS.Panel, TextStrokeTransparency = 1, Parent = levelBadge })

	local setHealth = bar(panel, UDim2.fromOffset(80, 8), UDim2.new(1, -90, 0, 24), COLORS.Health)
	local setEnergy = bar(panel, UDim2.fromOffset(80, 38), UDim2.new(1, -90, 0, 18), COLORS.Energy)
	local setXP = bar(panel, UDim2.fromOffset(80, 62), UDim2.new(1, -90, 0, 24), COLORS.XP)

	local function updateEnergy()
		local energy = player:GetAttribute("Energy") or 0
		local maxEnergy = player:GetAttribute("MaxEnergy") or 100
		setEnergy(energy, maxEnergy, ("%d / %d Energy"):format(math.floor(energy), maxEnergy))
	end
	player:GetAttributeChangedSignal("Energy"):Connect(updateEnergy)
	player:GetAttributeChangedSignal("MaxEnergy"):Connect(updateEnergy)
	updateEnergy()

	local goldText = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 0, -6),
		Size = UDim2.fromOffset(200, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextSize = 16,
		TextColor3 = COLORS.XP,
		Parent = panel,
	})

	local function updateStats()
		local level = player:GetAttribute("Level") or 1
		local xp = player:GetAttribute("XP") or 0
		local toNext = player:GetAttribute("XPToNext") or 0
		levelText.Text = tostring(level)
		if toNext > 0 then
			setXP(xp, toNext, ("%d / %d XP"):format(xp, toNext))
		else
			setXP(1, 1, "MAX LEVEL")
		end
		goldText.Text = ("%d Gold"):format(player:GetAttribute("Gold") or 0)
	end
	for _, name in { "Level", "XP", "XPToNext", "Gold" } do
		player:GetAttributeChangedSignal(name):Connect(updateStats)
	end
	updateStats()

	local function trackCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local function updateHealth()
			setHealth(humanoid.Health, humanoid.MaxHealth, ("%d / %d HP"):format(math.ceil(humanoid.Health), humanoid.MaxHealth))
		end
		humanoid.HealthChanged:Connect(updateHealth)
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateHealth)
		updateHealth()
	end
	player.CharacterAdded:Connect(trackCharacter)
	if player.Character then
		task.spawn(trackCharacter, player.Character)
	end

	Remotes.LevelUp.OnClientEvent:Connect(function(level: number, points: number)
		popup(gui, ("LEVEL UP!  Lv. %d"):format(level), COLORS.XP, 44)
		task.delay(0.25, popup, gui, ("+%d stat points"):format(points), COLORS.Text, 22)
	end)
	Remotes.Notify.OnClientEvent:Connect(function(message: string)
		popup(gui, message, COLORS.Text, 26)
	end)

	-- Tell the player if progress won't save (e.g. Studio API access is off).
	local function checkSaving()
		if player:GetAttribute("DataLoaded") and player:GetAttribute("Saving") == false then
			popup(gui, "Progress is not saving this session", Color3.fromRGB(255, 120, 100), 22)
		end
	end
	player:GetAttributeChangedSignal("DataLoaded"):Connect(checkSaving)
	checkSaving()
end

return HUD
