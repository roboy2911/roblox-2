-- What you see when things happen to you: getting bitten (red flash,
-- shake, damage number over your head) and earning XP and gold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HitEffects = require(script.Parent.Parent.Combat.HitEffects)

local player = Players.LocalPlayer

local XP_COLOR = Color3.fromRGB(150, 220, 255)
local GOLD_COLOR = Color3.fromRGB(255, 205, 70)
local HURT_COLOR = Color3.fromRGB(255, 70, 60)

local Feedback = {}

local hurtFlash: Frame

local function onPlayerHit(_enemy: Model, damage: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		HitEffects.FloatingText(root.Position + Vector3.new(0, 3, 0), "-" .. damage, HURT_COLOR, 30)
	end
	HitEffects.Shake(1.1, 0.2)
	hurtFlash.BackgroundTransparency = 0.6
	TweenService:Create(hurtFlash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

local function onReward(position: Vector3, xp: number, gold: number)
	local spot = position + Vector3.new(0, 2.5, 0)
	if xp > 0 then
		HitEffects.FloatingText(spot, ("+%d XP"):format(xp), XP_COLOR, 30)
	end
	if gold > 0 then
		HitEffects.FloatingText(spot - Vector3.new(0, 0.9, 0), ("+%d Gold"):format(gold), GOLD_COLOR, 26, 0.15)
	end
end

function Feedback.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HurtFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -1
	gui.Parent = player:WaitForChild("PlayerGui")

	hurtFlash = Instance.new("Frame")
	hurtFlash.Size = UDim2.fromScale(1, 1)
	hurtFlash.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	hurtFlash.BackgroundTransparency = 1
	hurtFlash.BorderSizePixel = 0
	hurtFlash.Active = false
	hurtFlash.Parent = gui

	Remotes.PlayerHit.OnClientEvent:Connect(onPlayerHit)
	Remotes.Reward.OnClientEvent:Connect(onReward)
end

return Feedback
