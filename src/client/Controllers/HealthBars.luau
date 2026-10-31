-- Draws a name, level and HP bar over everything tagged Damageable
-- (training dummies now, enemies and bosses later).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local TAG = "Damageable"
local MAX_DISTANCE = 80

local HealthBars = {}

local bars: { [Model]: BillboardGui } = {}

local function create(model: Model)
	if bars[model] or not model:IsA("Model") then
		return
	end
	local root = model.PrimaryPart or model:WaitForChild("Root", 5)
	if not root or not model.Parent then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Adornee = root :: BasePart
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetAttribute("BarHeight") or 6, 0)
	gui.MaxDistance = MAX_DISTANCE
	gui.AlwaysOnTop = true
	gui.Parent = player:WaitForChild("PlayerGui")

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.fromRGB(255, 244, 220)
	title.TextStrokeTransparency = 0.4
	title.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(10, 22)
	back.Size = UDim2.new(1, -20, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(40, 30, 26)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 4)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 14, 10)
	stroke.Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(196, 52, 52)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local function update()
		local health = model:GetAttribute("Health") or 0
		local maxHealth = model:GetAttribute("MaxHealth") or 1
		local dead = model:GetAttribute("Dead")
		title.Text = if dead
			then "Defeated!"
			else ("%s  Lv. %d"):format(model:GetAttribute("DisplayName") or model.Name, model:GetAttribute("Level") or 1)
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(math.clamp(health / maxHealth, 0, 1), 1) }):Play()
	end
	for _, name in { "Health", "MaxHealth", "Dead", "DisplayName", "Level" } do
		model:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
	bars[model] = gui
end

local function remove(model: Instance)
	local gui = bars[model :: Model]
	if gui then
		gui:Destroy()
		bars[model :: Model] = nil
	end
end

function HealthBars.Start()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		task.spawn(create, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)
	for _, model in CollectionService:GetTagged(TAG) do
		task.spawn(create, model)
	end
end

return HealthBars
