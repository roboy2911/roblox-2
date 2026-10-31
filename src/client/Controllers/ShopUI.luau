-- The Gem Merchant's shop window. Opens when you press E at the merchant.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(28, 22, 18),
	Card = Color3.fromRGB(48, 38, 30),
	Border = Color3.fromRGB(196, 160, 82),
	Text = Color3.fromRGB(255, 244, 220),
	Muted = Color3.fromRGB(190, 175, 150),
	Gold = Color3.fromRGB(255, 205, 70),
	Button = Color3.fromRGB(70, 120, 60),
	Disabled = Color3.fromRGB(80, 70, 62),
	Danger = Color3.fromRGB(140, 50, 40),
}

local ShopUI = {}

local window: Frame
local isOpen = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function text(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextColor3 = COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l:SetAttribute("Content", true)
	return l
end

local function button(label: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(120, 36)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = COLORS.Text
	b.Text = label
	corner(b, 8)
	local s = Instance.new("UIStroke")
	s.Color = COLORS.Border
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	b.Activated:Connect(onClick)
	return b
end

local function close()
	isOpen = false
	window.Visible = false
end

local function show(data)
	if not data then
		return
	end
	for _, child in window:GetDescendants() do
		if child:GetAttribute("Content") then
			child:Destroy()
		end
	end

	text({ Text = data.Name, Font = Enum.Font.Fantasy, TextSize = 28, TextColor3 = COLORS.Border, Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -70, 0, 32), Parent = window })
	text({ Text = '"' .. data.Greeting .. '"', TextSize = 15, Font = Enum.Font.GothamMedium, TextColor3 = COLORS.Muted, Position = UDim2.fromOffset(18, 46), Size = UDim2.new(1, -36, 0, 36), Parent = window })
	text({ Text = ("Your gold: %d"):format(data.Gold), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = COLORS.Gold, Position = UDim2.fromOffset(18, 82), Size = UDim2.new(1, -36, 0, 20), Parent = window })

	for i, item in data.Items do
		local card = Instance.new("Frame")
		card:SetAttribute("Content", true)
		card.Position = UDim2.fromOffset(18, 110 + (i - 1) * 140)
		card.Size = UDim2.new(1, -36, 0, 130)
		card.BackgroundColor3 = COLORS.Card
		card.Parent = window
		corner(card, 8)

		text({ Text = item.Name, Font = Enum.Font.Fantasy, TextSize = 24, TextColor3 = item.Color, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -150, 0, 26), Parent = card })
		text({ Text = item.Rarity, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = COLORS.Muted, Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -150, 0, 16), Parent = card })
		local lines = {}
		for _, move in item.Moves do
			table.insert(lines, ("%s  %s  (Lv. %d)"):format(move.Key, move.Name, move.Level))
		end
		text({ Text = table.concat(lines, "\n"), TextSize = 14, Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -150, 0, 54), Parent = card })

		local current = data.CurrentGem
		if current ~= "" and current ~= item.Id and Gems.List[current] then
			text({ Text = "Replaces your " .. Gems.List[current].DisplayName, TextSize = 12, TextColor3 = Color3.fromRGB(230, 120, 100), Position = UDim2.fromOffset(12, 110), Size = UDim2.new(1, -150, 0, 16), Parent = card })
		end

		local price = text({ Text = ("%d Gold"):format(item.Price), Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = COLORS.Gold, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 22), Size = UDim2.fromOffset(120, 20), Parent = card })
		price:SetAttribute("Content", true)
		local canAfford = data.Gold >= item.Price
		local label = if item.Owned then "Owned" elseif canAfford then "Buy & Eat" else "Not enough gold"
		local b = button(label, if item.Owned or not canAfford then COLORS.Disabled else COLORS.Button, function()
			if not item.Owned and canAfford then
				Remotes.ShopAction:FireServer("Buy", item.Id)
			end
		end)
		b.TextSize = if canAfford or item.Owned then 15 else 12
		b.AutoButtonColor = canAfford and not item.Owned
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, -12, 0, 50)
		b:SetAttribute("Content", true)
		b.Parent = card
	end

	window.Size = UDim2.new(0.92, 0, 0, 124 + #data.Items * 140)
	isOpen = true
	window.Visible = true
end

function ShopUI.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Shop"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	window = Instance.new("Frame")
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.45)
	window.Size = UDim2.new(0.92, 0, 0, 264)
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
	limit.MaxSize = Vector2.new(520, 600)
	limit.Parent = window

	local x = button("X", COLORS.Danger, close)
	x.Size = UDim2.fromOffset(34, 34)
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -12, 0, 12)
	x.Parent = window

	Remotes.ShopDialog.OnClientEvent:Connect(show)

	-- Close when you walk away from the merchant.
	RunService.Heartbeat:Connect(function()
		if not isOpen then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local offset = root and (root.Position - Gems.Merchant.Position) * Vector3.new(1, 0, 1)
		if not offset or offset.Magnitude > 22 then
			close()
		end
	end)
end

return ShopUI
