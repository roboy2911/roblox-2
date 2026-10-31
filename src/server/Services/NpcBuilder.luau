-- Builds a standing NPC (quest giver, merchant...): our textured model, a
-- neck joint so clients can turn the head toward players, and a prompt.
-- Clients animate anything tagged "Npc" (see NpcController).

local CollectionService = game:GetService("CollectionService")

local AssetService = require(script.Parent.AssetService)
local Props = require(script.Parent.Props)

local NPC_TAG = "Npc"
local HEIGHT = 5.8

local NpcBuilder = {}

local function standIn(robeColor: Color3): Model
	local model = Instance.new("Model")
	local robe = Instance.new("Part")
	robe.Name = "Body"
	robe.Size = Vector3.new(2, 4.6, 1.4)
	robe.CFrame = CFrame.new(0, 2.3, 0)
	robe.Color = robeColor
	robe.Material = Enum.Material.SmoothPlastic
	robe.Anchored = true
	robe.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.1, 1.1, 1.1)
	head.CFrame = CFrame.new(0, 5.1, 0)
	head.Color = Color3.fromRGB(217, 163, 128)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

export type Options = {
	Model: string, -- key in Config/Assets Models
	DisplayName: string,
	Position: Vector3, -- on the ground (Y is found automatically)
	Facing: Vector3?, -- direction to face; defaults to toward spawn
	Parent: Instance,
	StandInColor: Color3?,
	PromptText: string,
	OnPrompt: (player: Player) -> (),
	PromptDistance: number?,
}

-- Returns the NPC model and the ground position it stands on.
function NpcBuilder.Spawn(options: Options): (Model, Vector3)
	local y = Props.GroundY(options.Position)
	local position = Vector3.new(options.Position.X, y, options.Position.Z)
	local facing = options.Facing or (Vector3.zero - position)
	facing *= Vector3.new(1, 0, 1)
	facing = if facing.Magnitude > 0.01 then facing.Unit else -Vector3.zAxis

	local model = AssetService.Model(options.Model) or standIn(options.StandInColor or Color3.fromRGB(56, 92, 51))
	model.Name = options.DisplayName
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * HEIGHT / size.Y)

	local body = model:FindFirstChild("Body") :: BasePart
	local head = model:FindFirstChild("Head") :: BasePart
	if body and head then
		local neck = CFrame.new(head.Position - Vector3.new(0, head.Size.Y * 0.4, 0))
		head.Anchored = false
		head.CanCollide = false
		local joint = Instance.new("Motor6D")
		joint.Name = "Joint"
		joint.Part0 = body
		joint.Part1 = head
		joint.C0 = body.CFrame:ToObjectSpace(neck)
		joint.C1 = head.CFrame:ToObjectSpace(neck)
		joint.Parent = head
	end

	model:PivotTo(CFrame.lookAt(position, position + facing))
	model:SetAttribute("BarHeight", HEIGHT + 1)
	model.Parent = options.Parent
	CollectionService:AddTag(model, NPC_TAG)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.PromptText
	prompt.ObjectText = options.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = options.PromptDistance or 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body or model:FindFirstChildWhichIsA("BasePart")
	prompt.Triggered:Connect(options.OnPrompt)

	return model, position
end

-- True if the player's character is within `distance` of the NPC.
function NpcBuilder.IsNear(player: Player, model: Model?, distance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return model ~= nil and root ~= nil and (root.Position - model:GetPivot().Position).Magnitude <= distance
end

return NpcBuilder
