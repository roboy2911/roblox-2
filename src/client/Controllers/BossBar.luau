-- Big HP bar at the top of the screen when you're near a living boss.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local SHOW_DISTANCE = 90

local BossBar = {}

function BossBar.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossBar"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.new(0.6, 0, 0, 46)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 46)
	limit.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Fantasy
	title.TextSize = 22
	title.TextColor3 = Color3.fromRGB(255, 220, 150)
	title.TextStrokeTransparency = 0.3
	title.Parent = frame

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 24)
	back.Size = UDim2.new(1, 0, 0, 18)
	back.BackgroundColor3 = Color3.fromRGB(35, 25, 22)
	back.Parent = frame
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(196, 160, 82)
	stroke.Thickness = 1.5
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(190, 40, 35)
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

	local numbers = Instance.new("TextLabel")
	numbers.Size = UDim2.fromScale(1, 1)
	numbers.BackgroundTransparency = 1
	numbers.Font = Enum.Font.GothamBold
	numbers.TextSize = 13
	numbers.TextColor3 = Color3.new(1, 1, 1)
	numbers.TextStrokeTransparency = 0.4
	numbers.ZIndex = 2
	numbers.Parent = back

	RunService.Heartbeat:Connect(function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local boss, bestDistance = nil, SHOW_DISTANCE
		if root then
			for _, model in CollectionService:GetTagged("Damageable") do
				if model:GetAttribute("Boss") and not model:GetAttribute("Dead") and model.Parent then
					local distance = (model:GetPivot().Position - root.Position).Magnitude
					if distance < bestDistance then
						boss, bestDistance = model, distance
					end
				end
			end
		end
		frame.Visible = boss ~= nil
		if boss then
			local health = boss:GetAttribute("Health") or 0
			local maxHealth = boss:GetAttribute("MaxHealth") or 1
			title.Text = ("%s  Lv. %d"):format(boss:GetAttribute("DisplayName") or boss.Name, boss:GetAttribute("Level") or 1)
			fill.Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1)
			numbers.Text = ("%d / %d"):format(math.ceil(health), maxHealth)
		end
	end)
end

return BossBar
