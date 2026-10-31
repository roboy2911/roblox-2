-- Little touches on things in the world:
--   gems lying under trees spin, bob, glow and give off embers
--   players with their gem slot selected have flames on their fists
--   the sea's surface drifts, and you wade slowly through water
--   a banner shows the island's name when you arrive

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Images = require(ReplicatedStorage.Shared.Images)
local World = require(ReplicatedStorage.Shared.Config.World)
local TweenService = game:GetService("TweenService")

local Players = game:GetService("Players")

local PICKUP_TAG = "GemPickup"
local FIST_FX = "FireFist"

local WorldEffects = {}

local pickups: { [Model]: CFrame } = {}

local function add(model: Instance)
	if not model:IsA("Model") or pickups[model] then
		return
	end
	local gem = Gems.List[model:GetAttribute("GemId") or ""]
	local color = if gem then gem.Color else Color3.new(1, 1, 1)
	local core = model:FindFirstChildWhichIsA("BasePart")
	if core then
		local a = Instance.new("Attachment")
		a.Parent = core
		local halo = Instance.new("ParticleEmitter")
		halo.Texture = Images.Get("FxGlow")
		halo.Color = ColorSequence.new(color)
		halo.LightEmission = 1
		halo.Size = NumberSequence.new(3.5)
		halo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) })
		halo.Lifetime = NumberRange.new(0.8)
		halo.Rate = 4
		halo.Speed = NumberRange.new(0)
		halo.LockedToPart = true
		halo.Parent = a
		local embers = Instance.new("ParticleEmitter")
		embers.Texture = Images.Get("FxSpark")
		embers.Color = ColorSequence.new(color)
		embers.LightEmission = 1
		embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		embers.Lifetime = NumberRange.new(0.8, 1.4)
		embers.Rate = 8
		embers.Speed = NumberRange.new(1, 2.5)
		embers.SpreadAngle = Vector2.new(40, 40)
		embers.EmissionDirection = Enum.NormalId.Top
		embers.Parent = a
	end
	pickups[model] = model:GetPivot()
end

-- Adds or removes fist flames to match each player's selected slot.
local function updateFists()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then
			continue
		end
		local gem = Gems.List[player:GetAttribute("Gem") or ""]
		local wanted = player:GetAttribute("Slot") == "Gem" and gem ~= nil
		for _, handName in { "RightHand", "LeftHand" } do
			local hand = character:FindFirstChild(handName)
			if not hand then
				continue
			end
			local existing = hand:FindFirstChild(FIST_FX)
			if wanted and not existing then
				local a = Instance.new("Attachment")
				a.Name = FIST_FX
				a.Parent = hand
				local e = Instance.new("ParticleEmitter")
				e.Texture = Images.Get("FxFlame")
				e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), gem.Color)
				e.LightEmission = 1
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
				e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
				e.Lifetime = NumberRange.new(0.2, 0.35)
				e.Speed = NumberRange.new(0.5, 1.5)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Acceleration = Vector3.new(0, 6, 0)
				e.Rate = 30
				e.Parent = a
			elseif not wanted and existing then
				existing:Destroy()
			end
		end
	end
end

local WADE_SPEED = 8
local WALK_SPEED = 16

local function showIslandBanner(gui: ScreenGui, islandId: string)
	local island = World.IslandById(islandId)
	if not island then
		return
	end
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.fromScale(0.5, 0.14)
	frame.Size = UDim2.fromOffset(500, 80)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local function line(text: string, y: number, size: number, color: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(0, y)
		l.Size = UDim2.new(1, 0, 0, size + 6)
		l.Font = Enum.Font.Fantasy
		l.Text = text
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.3
		l.TextTransparency = 1
		l.TextStrokeTransparency = 1
		l.Parent = frame
		TweenService:Create(l, TweenInfo.new(0.6), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
		task.delay(3, function()
			TweenService:Create(l, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end)
	end
	line(island.Name, 0, 40, Color3.fromRGB(255, 236, 190))
	line(island.Levels, 46, 22, Color3.fromRGB(196, 160, 82))
	task.delay(4.2, function()
		frame:Destroy()
	end)
end

function WorldEffects.Start()
	local player = Players.LocalPlayer
	local bannerGui = Instance.new("ScreenGui")
	bannerGui.Name = "IslandBanner"
	bannerGui.ResetOnSpawn = false
	bannerGui.Parent = player:WaitForChild("PlayerGui")
	player:GetAttributeChangedSignal("Island"):Connect(function()
		showIslandBanner(bannerGui, player:GetAttribute("Island"))
	end)

	local wading = false
	RunService.Heartbeat:Connect(function(dt)
		-- Drift the sea texture.
		local greenvale = workspace:FindFirstChild("Greenvale")
		local sea = greenvale and greenvale:FindFirstChild("Sea")
		local texture = sea and sea:FindFirstChildWhichIsA("Texture")
		if texture then
			texture.OffsetStudsU += dt * 1.5
			texture.OffsetStudsV += dt * 0.6
		end
		-- Wade slowly when standing in the sea.
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root then
			local inWater = root.Position.Y < World.WaterLevel + 1 and humanoid.SeatPart == nil
			if inWater ~= wading then
				wading = inWater
				humanoid.WalkSpeed = if inWater then WADE_SPEED else WALK_SPEED
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			updateFists()
		end
	end)

	CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(function(model)
		task.spawn(add, model)
	end)
	CollectionService:GetInstanceRemovedSignal(PICKUP_TAG):Connect(function(model)
		pickups[model :: Model] = nil
	end)
	for _, model in CollectionService:GetTagged(PICKUP_TAG) do
		task.spawn(add, model)
	end

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, base in pickups do
			if not model.Parent then
				pickups[model] = nil
				continue
			end
			model:PivotTo(base * CFrame.new(0, 0.6 + math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, t * 1.5, 0))
		end
	end)
end

return WorldEffects
