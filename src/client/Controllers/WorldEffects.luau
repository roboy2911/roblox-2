-- Little touches on things in the world. Right now: gems lying under trees
-- spin, bob, glow and give off embers so they're easy to spot.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Images = require(ReplicatedStorage.Shared.Images)

local PICKUP_TAG = "GemPickup"

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

function WorldEffects.Start()
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
