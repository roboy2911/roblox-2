-- Quest dialog (opens when you talk to a quest giver) and the quest
-- tracker in the top right corner.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(28, 22, 18),
	Card = Color3.fromRGB(48, 38, 30),
	Border = Color3.fromRGB(196, 160, 82),
	Text = Color3.fromRGB(255, 244, 220),
	Muted = Color3.fromRGB(190, 175, 150),
	XP = Color3.fromRGB(150, 220, 255),
	Gold = Color3.fromRGB(255, 205, 70),
	Button = Color3.fromRGB(70, 120, 60),
	Danger = Color3.fromRGB(140, 50, 40),
	Locked = Color3.fromRGB(80, 70, 62),
}

local QuestUI = {}

local gui: ScreenGui
local dialog: Frame
local openGiver: string? = nil

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function text(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Gotham
	l.TextColor3 = COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	for key, value in props do
		(l :: any)[key] = value
	end
	return l
end

local function button(label: string, color: Color3, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(110, 34)
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.TextColor3 = COLORS.Text
	b.Text = label
	corner(b, 8)
	stroke(b, COLORS.Border, 1)
	b.Activated:Connect(onClick)
	return b
end

local function close()
	openGiver = nil
	dialog.Visible = false
end

local function questCard(parent: Instance, quest, active, giverId: string, order: number)
	local card = Instance.new("Frame")
	card.LayoutOrder = order
	card.Size = UDim2.new(1, 0, 0, 118)
	card.BackgroundColor3 = COLORS.Card
	card.Parent = parent
	corner(card, 8)

	text({ Text = quest.Title, Font = Enum.Font.Fantasy, TextSize = 22, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -140, 0, 24), Parent = card })
	text({ Text = quest.Description, TextSize = 14, TextColor3 = COLORS.Muted, Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -140, 0, 36), Parent = card })
	text({
		Text = ("Defeat %d %s%s"):format(quest.Count, quest.Enemy, (if quest.Count > 1 then "s" else "")),
		Font = Enum.Font.GothamBold, TextSize = 14, Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -140, 0, 18), Parent = card,
	})
	local reward = text({ RichText = true, TextSize = 14, Position = UDim2.fromOffset(12, 94), Size = UDim2.new(1, -140, 0, 18), Parent = card })
	reward.Text = ('<font color="#96DCFF">+%d XP</font>   <font color="#FFCD46">+%d Gold</font>'):format(quest.XP, quest.Gold)

	local slot = Instance.new("Frame")
	slot.BackgroundTransparency = 1
	slot.AnchorPoint = Vector2.new(1, 0.5)
	slot.Position = UDim2.new(1, -12, 0.5, 0)
	slot.Size = UDim2.fromOffset(110, 60)
	slot.Parent = card

	if quest.Locked then
		text({ Text = ("Requires\nLv. %d"):format(quest.MinLevel), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = slot })
		card.BackgroundColor3 = COLORS.Locked
	elseif active and active.Id == quest.Id then
		text({ Text = ("In progress\n%d / %d"):format(active.Progress, active.Count), Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = COLORS.Gold,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = slot })
	elseif active then
		text({ Text = "Finish your\ncurrent quest", TextSize = 13, TextColor3 = COLORS.Muted,
			TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = slot })
	else
		local accept = button("Accept", COLORS.Button, function()
			Remotes.QuestAction:FireServer("Accept", giverId, quest.Id)
		end)
		accept.AnchorPoint = Vector2.new(0, 0.5)
		accept.Position = UDim2.fromScale(0, 0.5)
		accept.Parent = slot
	end
end

local function showDialog(data)
	if not data then
		return
	end
	openGiver = data.GiverId
	for _, child in dialog:GetChildren() do
		if child:GetAttribute("Content") then
			child:Destroy()
		end
	end

	local header = text({ Text = data.Name, Font = Enum.Font.Fantasy, TextSize = 30, TextColor3 = COLORS.Border, Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -70, 0, 34), Parent = dialog })
	header:SetAttribute("Content", true)
	local greeting = text({ Text = '"' .. data.Greeting .. '"', TextSize = 15, TextColor3 = COLORS.Muted, Font = Enum.Font.GothamMedium, Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -36, 0, 40), Parent = dialog })
	greeting:SetAttribute("Content", true)

	local list = Instance.new("Frame")
	list:SetAttribute("Content", true)
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(18, 94)
	list.Size = UDim2.new(1, -36, 1, -150)
	list.Parent = dialog
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	for i, quest in data.Quests do
		questCard(list, quest, data.Active, data.GiverId, i)
	end

	if data.Active then
		local abandon = button("Abandon quest", COLORS.Danger, function()
			Remotes.QuestAction:FireServer("Abandon", data.GiverId)
		end)
		abandon:SetAttribute("Content", true)
		abandon.Size = UDim2.fromOffset(150, 34)
		abandon.AnchorPoint = Vector2.new(0, 1)
		abandon.Position = UDim2.new(0, 18, 1, -14)
		abandon.Parent = dialog
	end

	dialog.Visible = true
end

local function buildDialog()
	dialog = Instance.new("Frame")
	dialog.Name = "QuestDialog"
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.45)
	dialog.Size = UDim2.new(0.92, 0, 0, 420)
	dialog.BackgroundColor3 = COLORS.Panel
	dialog.BackgroundTransparency = 0.05
	dialog.Visible = false
	dialog.Parent = gui
	corner(dialog, 12)
	stroke(dialog, COLORS.Border, 2)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 420)
	limit.Parent = dialog

	local x = button("X", COLORS.Danger, close)
	x.Size = UDim2.fromOffset(34, 34)
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -12, 0, 12)
	x.Parent = dialog
end

-- Top-right tracker: quest name, what to defeat, and a progress bar.
local function buildTracker()
	local tracker = Instance.new("Frame")
	tracker.Name = "QuestTracker"
	tracker.AnchorPoint = Vector2.new(1, 0)
	tracker.Position = UDim2.new(1, -16, 0, 16)
	tracker.Size = UDim2.fromOffset(240, 70)
	tracker.BackgroundColor3 = COLORS.Panel
	tracker.BackgroundTransparency = 0.25
	tracker.Visible = false
	tracker.Parent = gui
	corner(tracker, 10)
	stroke(tracker, COLORS.Border, 1.5)

	local title = text({ Font = Enum.Font.Fantasy, TextSize = 19, TextColor3 = COLORS.Border, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), Parent = tracker })
	local goal = text({ TextSize = 14, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 18), Parent = tracker })
	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(12, 50)
	back.Size = UDim2.new(1, -24, 0, 10)
	back.BackgroundColor3 = Color3.fromRGB(55, 45, 38)
	back.Parent = tracker
	corner(back, 5)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = COLORS.Gold
	fill.Parent = back
	corner(fill, 5)

	local function update()
		local title_ = player:GetAttribute("QuestTitle")
		if not title_ then
			tracker.Visible = false
			return
		end
		local progress = player:GetAttribute("QuestProgress") or 0
		local count = player:GetAttribute("QuestCount") or 1
		local enemy = player:GetAttribute("QuestEnemy") or "enemies"
		tracker.Visible = true
		title.Text = title_
		goal.Text = ("Defeat %ss: %d / %d"):format(enemy, progress, count)
		TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(math.clamp(progress / count, 0, 1), 1) }):Play()
	end
	for _, name in { "QuestTitle", "QuestProgress", "QuestCount", "QuestEnemy" } do
		player:GetAttributeChangedSignal(name):Connect(update)
	end
	update()
end

function QuestUI.Start()
	gui = Instance.new("ScreenGui")
	gui.Name = "Quests"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	buildDialog()
	buildTracker()
	Remotes.QuestDialog.OnClientEvent:Connect(showDialog)

	-- Close the dialog if you walk away from the giver.
	RunService.Heartbeat:Connect(function()
		if not openGiver then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local giver = Quests.Givers[openGiver]
		if not root or not giver then
			close()
			return
		end
		local offset = (root.Position - giver.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude > Quests.TalkDistance + 6 then
			close()
		end
	end)
end

return QuestUI
