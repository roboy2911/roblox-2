-- Makes quest givers feel alive: the head turns to look at you when you're
-- close, and a "!" floats over them while you don't have a quest.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local GIVER_TAG = "QuestGiver"
local LOOK_DISTANCE = 22
local MAX_TURN = math.rad(70)

local NpcController = {}

type Npc = { Model: Model, Neck: Motor6D?, Marker: BillboardGui, Yaw: number }
local npcs: { [Model]: Npc } = {}

local function add(model: Instance)
	if not model:IsA("Model") or npcs[model] then
		return
	end
	local head = model:WaitForChild("Head", 5)
	local neck = head and head:FindFirstChild("Joint")

	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.fromOffset(60, 70)
	marker.StudsOffsetWorldSpace = Vector3.new(0, (model:GetAttribute("BarHeight") or 6.5) + 0.6, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 120
	marker.Adornee = model:FindFirstChild("Body") or model:FindFirstChildWhichIsA("BasePart")
	marker.Parent = player:WaitForChild("PlayerGui")
	local mark = Instance.new("TextLabel")
	mark.Size = UDim2.fromScale(1, 1)
	mark.BackgroundTransparency = 1
	mark.Font = Enum.Font.Fantasy
	mark.Text = "!"
	mark.TextScaled = true
	mark.TextColor3 = Color3.fromRGB(255, 205, 70)
	mark.TextStrokeTransparency = 0
	mark.Parent = marker

	-- Billboards adorned to a part sit at its center; measure from the ground pivot instead.
	if marker.Adornee then
		local offset = model:GetPivot().Position.Y - (marker.Adornee :: BasePart).Position.Y
		marker.StudsOffsetWorldSpace += Vector3.new(0, offset, 0)
	end

	npcs[model] = { Model = model, Neck = neck and neck:IsA("Motor6D") and neck or nil, Marker = marker, Yaw = 0 }
end

local function step(dt: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hasQuest = (player:GetAttribute("QuestId") or "") ~= ""
	local t = os.clock()
	for model, npc in npcs do
		if not model.Parent then
			npc.Marker:Destroy()
			npcs[model] = nil
			continue
		end
		npc.Marker.Enabled = not hasQuest
		-- Bob the "!" gently.
		local label = npc.Marker:FindFirstChildWhichIsA("TextLabel")
		if label then
			label.Position = UDim2.fromOffset(0, math.sin(t * 3) * 4)
		end

		if npc.Neck then
			local target = 0
			local pivot = model:GetPivot()
			if root and (root.Position - pivot.Position).Magnitude < LOOK_DISTANCE then
				local localDir = pivot:VectorToObjectSpace(root.Position - pivot.Position)
				target = math.clamp(math.atan2(-localDir.X, -localDir.Z), -MAX_TURN, MAX_TURN)
			end
			npc.Yaw += (target - npc.Yaw) * math.min(1, dt * 5)
			npc.Neck.Transform = CFrame.Angles(math.sin(t * 1.3) * math.rad(2), npc.Yaw, 0)
		end
	end
end

function NpcController.Start()
	CollectionService:GetInstanceAddedSignal(GIVER_TAG):Connect(function(model)
		task.spawn(add, model)
	end)
	for _, model in CollectionService:GetTagged(GIVER_TAG) do
		task.spawn(add, model)
	end
	RunService.RenderStepped:Connect(step)
end

return NpcController
