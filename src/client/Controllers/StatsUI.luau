-- Stats menu: spend stat points (+1 / +10) and reset stats for gold.
-- Open it with the Stats button next to the HUD or the M key.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Leveling = require(ReplicatedStorage.Shared.Config.Leveling)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(28, 22, 18),
	Row = Color3.fromRGB(48, 38, 30),
	Border = Color3.fromRGB(196, 160, 82),
	Text = Color3.fromRGB(255, 244, 220),
	Muted = Color3.fromRGB(190, 175, 150),
	Button = Color3.fromRGB(70, 120, 60),
	Disabled = Color3.fromRGB(80, 70, 62),
	Danger = Color3.fromRGB(140, 50, 40),
	Gold = Color3.fromRGB(255, 205, 70),
}

local StatsUI = {}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextColor3 = COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

local function button(text: string, color: Color3, size: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = COLORS.Text
	b.Text = text
	corner(b, 6)
	local s = Instance.new("UIStroke")
	s.Color = COLORS.Border
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	return b
end

function StatsUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Stats"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Button next to the HUD, with a badge for unspent points.
	local open = button("Stats (M)", COLORS.Panel, UDim2.fromOffset(92, 32))
	open.AnchorPoint = Vector2.new(0, 1)
	open.Position = UDim2.new(0, 16, 1, -16)
	open.Parent = gui
	local badge = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 2), Size = UDim2.fromOffset(28, 20),
		BackgroundTransparency = 0, BackgroundColor3 = COLORS.Danger, Font = Enum.Font.GothamBold, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center, Parent = open })
	corner(badge, 10)

	local window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.45)
	window.Size = UDim2.new(0.92, 0, 0, 120 + #Leveling.StatNames * 58 + 56)
	window.BackgroundColor3 = COLORS.Panel
	window.BackgroundTransparency = 0.05
	window.Visible = false
	window.Parent = gui
	corner(window, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Border
	stroke.Thickness = 2
	stroke.Parent = window
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(480, 600)
	limit.Parent = window

	label({ Text = "Stats", Font = Enum.Font.Fantasy, TextSize = 30, TextColor3 = COLORS.Border, Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -70, 0, 34), Parent = window })
	local pointsText = label({ Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLORS.Gold, Position = UDim2.fromOffset(18, 52), Size = UDim2.new(1, -36, 0, 22), Parent = window })
	label({ Text = "Strong at one thing, or good at several. That's your build.", TextSize = 13, TextColor3 = COLORS.Muted,
		Position = UDim2.fromOffset(18, 76), Size = UDim2.new(1, -36, 0, 18), Parent = window })

	local close = button("X", COLORS.Danger, UDim2.fromOffset(34, 34))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Parent = window

	type Row = { Value: TextLabel, Plus1: TextButton, Plus10: TextButton }
	local rows: { [string]: Row } = {}
	for i, name in Leveling.StatNames do
		local info = Leveling.StatInfo[name]
		local row = Instance.new("Frame")
		row.Position = UDim2.fromOffset(18, 104 + (i - 1) * 58)
		row.Size = UDim2.new(1, -36, 0, 50)
		row.BackgroundColor3 = COLORS.Row
		row.Parent = window
		corner(row, 8)
		label({ Text = info.DisplayName, Font = Enum.Font.GothamBold, TextSize = 16, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -200, 0, 20), Parent = row })
		label({ Text = info.Effect, TextSize = 12, TextColor3 = COLORS.Muted, Position = UDim2.fromOffset(12, 27), Size = UDim2.new(1, -200, 0, 16), Parent = row })
		local value = label({ Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -112, 0.5, 0), Size = UDim2.fromOffset(60, 24), Parent = row })
		local plus1 = button("+1", COLORS.Button, UDim2.fromOffset(44, 32))
		plus1.AnchorPoint = Vector2.new(1, 0.5)
		plus1.Position = UDim2.new(1, -58, 0.5, 0)
		plus1.Parent = row
		local plus10 = button("+10", COLORS.Button, UDim2.fromOffset(44, 32))
		plus10.AnchorPoint = Vector2.new(1, 0.5)
		plus10.Position = UDim2.new(1, -8, 0.5, 0)
		plus10.Parent = row
		plus1.Activated:Connect(function()
			Remotes.StatAction:FireServer("Spend", name, 1)
		end)
		plus10.Activated:Connect(function()
			Remotes.StatAction:FireServer("Spend", name, 10)
		end)
		rows[name] = { Value = value, Plus1 = plus1, Plus10 = plus10 }
	end

	-- Reset: click once to see the price, again to confirm.
	local reset = button("", COLORS.Danger, UDim2.new(1, -36, 0, 38))
	reset.AnchorPoint = Vector2.new(0, 1)
	reset.Position = UDim2.new(0, 18, 1, -14)
	reset.Parent = window
	local confirming = false

	local function refresh()
		local points = player:GetAttribute("StatPoints") or 0
		badge.Visible = points > 0
		badge.Text = tostring(points)
		pointsText.Text = ("Points to spend: %d"):format(points)
		for name, row in rows do
			row.Value.Text = tostring(player:GetAttribute("Stat_" .. name) or 0)
			for _, b in { row.Plus1, row.Plus10 } do
				b.BackgroundColor3 = if points > 0 then COLORS.Button else COLORS.Disabled
				b.AutoButtonColor = points > 0
			end
		end
		local cost = Leveling.ResetCost(player:GetAttribute("Level") or 1)
		reset.Text = if confirming
			then ("Click again to reset for %d gold"):format(cost)
			else ("Reset stats (%d gold)"):format(cost)
	end

	reset.Activated:Connect(function()
		if confirming then
			confirming = false
			Remotes.StatAction:FireServer("Reset")
		else
			confirming = true
			task.delay(3, function()
				confirming = false
				refresh()
			end)
		end
		refresh()
	end)

	local function toggle()
		window.Visible = not window.Visible
		confirming = false
		refresh()
	end
	open.Activated:Connect(toggle)
	close.Activated:Connect(toggle)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.KeyCode == Enum.KeyCode.M then
			toggle()
		end
	end)

	player.AttributeChanged:Connect(function(name)
		if name == "StatPoints" or name == "Level" or string.sub(name, 1, 5) == "Stat_" then
			refresh()
		end
	end)
	refresh()
end

return StatsUI
