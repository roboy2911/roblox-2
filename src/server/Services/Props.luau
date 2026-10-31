-- Places our textured props (barrels, hay bales, signs, dirt pads...).
-- If a model can't be loaded, a plain block of about the right size is
-- used so the map still works.

local AssetService = require(script.Parent.AssetService)

local Props = {}

-- Stand-in sizes and colors, only used if a model can't be loaded.
local FALLBACKS = {
	Barrel = { Size = Vector3.new(2, 2.6, 2), Color = Color3.fromRGB(110, 72, 40) },
	HayBale = { Size = Vector3.new(3, 2, 2), Color = Color3.fromRGB(214, 184, 96) },
	Crate = { Size = Vector3.new(2.4, 2.4, 2.4), Color = Color3.fromRGB(150, 110, 65) },
	Tent = { Size = Vector3.new(5.2, 4, 7.2), Color = Color3.fromRGB(115, 40, 30) },
	Campfire = { Size = Vector3.new(3, 0.6, 3), Color = Color3.fromRGB(70, 66, 62) },
	Stall = { Size = Vector3.new(5, 5.5, 2.5), Color = Color3.fromRGB(140, 95, 55) },
	DirtPad = { Size = Vector3.new(40, 0.3, 40), Color = Color3.fromRGB(110, 86, 58) },
	Sign = { Size = Vector3.new(7, 6, 0.4), Color = Color3.fromRGB(120, 80, 45) },
}

local function fallback(name: string): Model
	local info = FALLBACKS[name] or { Size = Vector3.new(2, 2, 2), Color = Color3.fromRGB(150, 150, 150) }
	local model = Instance.new("Model")
	model.Name = name
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = info.Size
	part.Color = info.Color
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(0, info.Size.Y / 2, 0)
	part.Parent = model
	model.WorldPivot = CFrame.new()
	return model
end

-- Places a prop standing on `position`, facing `facing` (a direction).
-- `scale` grows or shrinks it (1 = as modeled).
function Props.Place(name: string, position: Vector3, facing: Vector3?, parent: Instance, scale: number?): Model
	local model = AssetService.Model(name) or fallback(name)
	if scale and scale ~= 1 then
		model:ScaleTo(scale)
	end
	local look = facing and (facing * Vector3.new(1, 0, 1))
	if look and look.Magnitude > 0.01 then
		model:PivotTo(CFrame.lookAt(position, position + look))
	else
		model:PivotTo(CFrame.new(position))
	end
	model.Parent = parent
	return model
end

-- A signpost with text on both sides of the board.
function Props.Sign(text: string, position: Vector3, facing: Vector3, parent: Instance): Model
	local model = Props.Place("Sign", position, facing, parent)
	local board = model:FindFirstChild("Board") :: BasePart?
	if not board then
		-- Stand-in sign: put the text on the whole block.
		board = model:FindFirstChildWhichIsA("BasePart")
	end
	if not board then
		return model
	end

	-- An invisible panel that matches the board, facing the sign's direction,
	-- so the text lands on the board's big faces whichever way it was modeled.
	local _, size = model:GetBoundingBox()
	local panel = Instance.new("Part")
	panel.Name = "SignText"
	panel.Anchored = true
	panel.CanCollide = false
	panel.CanQuery = false
	panel.CanTouch = false
	panel.Transparency = 1
	local boardHeight = math.min(board.Size.Y, size.Y)
	-- Slightly thicker than the board so the text sits just outside it.
	local thickness = math.min(board.Size.X, board.Size.Z) + 0.06
	panel.Size = Vector3.new(math.max(board.Size.X, board.Size.Z), boardHeight, thickness)
	panel.CFrame = CFrame.lookAt(board.Position, board.Position + model:GetPivot().LookVector)
	panel.Parent = model

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.Parent = panel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Fantasy
		label.Text = text
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 240, 205)
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
	end
	return model
end

-- Ground height under a point (ignoring the given instances), or 0.
function Props.GroundY(position: Vector3, ignore: { Instance }?): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	local result = workspace:Raycast(Vector3.new(position.X, position.Y + 300, position.Z), Vector3.new(0, -600, 0), params)
	return if result then result.Position.Y else 0
end

return Props
