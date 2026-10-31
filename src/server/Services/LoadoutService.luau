-- Build slots (1 Style, 2 Weapon, 3 Gem): which one is selected, owned and
-- equipped weapons, and the weapon model in the player's hand.
-- Player attributes: Slot, Style, Weapon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Loadout = require(ReplicatedStorage.Shared.Loadout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AssetService = require(script.Parent.AssetService)
local DataService = require(script.Parent.DataService)

local LoadoutService = {}

local WEAPON_NAME = "EquippedWeapon"

local function weaponModel(weapon): Model
	local model = AssetService.Model(weapon.Model)
	if not model then
		model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Name = "Weapon"
		part.Size = Vector3.new(0.25, weapon.Length, 0.1)
		part.CFrame = CFrame.new(0, weapon.Length / 2, 0)
		part.Color = Color3.fromRGB(150, 152, 158)
		part.Material = Enum.Material.SmoothPlastic
		part.Parent = model
		model.WorldPivot = CFrame.new()
	end
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * weapon.Length / size.Y)
	return model
end

-- Puts the weapon in the right hand (blade forward and a little down),
-- or takes it away.
local function refreshHand(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild(WEAPON_NAME)
	if old then
		old:Destroy()
	end
	local profile = DataService.Get(player)
	local weapon = profile and Combat.Weapons[profile.Data.Weapon]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not weapon or player:GetAttribute("Slot") ~= "Weapon" or not hand or not hand:IsA("BasePart") then
		return
	end

	local model = weaponModel(weapon)
	model.Name = WEAPON_NAME
	local pivot = model:GetPivot()
	local main = model:FindFirstChildWhichIsA("BasePart") :: BasePart
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			if part ~= main then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = main
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end

	local grip = pivot * CFrame.new(0, weapon.Grip, 0)
	local weld = Instance.new("Weld")
	weld.Name = "Grip"
	weld.Part0 = hand
	weld.Part1 = main
	weld.C0 = CFrame.new(0, -hand.Size.Y * 0.4, 0) * CFrame.Angles(math.rad(-120), 0, 0)
	weld.C1 = main.CFrame:ToObjectSpace(grip)
	weld.Parent = main

	-- Trail along the blade (clients turn it on during swings).
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.CFrame = main.CFrame:ToObjectSpace(pivot * CFrame.new(0, weapon.Grip + 0.6, 0))
	base.Parent = main
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.CFrame = main.CFrame:ToObjectSpace(pivot * CFrame.new(0, weapon.Length * 0.97, 0))
	tip.Parent = main
	local trail = Instance.new("Trail")
	trail.Name = "WeaponTrail"
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.18
	trail.Enabled = false
	trail.Parent = main

	model.Parent = character
end

function LoadoutService.Select(player: Player, slot: string)
	local profile = DataService.Get(player)
	if not profile or not table.find(Loadout.Slots, slot) then
		return
	end
	if slot == "Weapon" and not Combat.Weapons[profile.Data.Weapon] then
		Remotes.Notify:FireClient(player, "No weapon yet. Visit the Blacksmith!")
		return
	elseif slot == "Gem" and profile.Data.Gem == "" then
		Remotes.Notify:FireClient(player, "No gem yet. Find one under a tree or visit the Gem Merchant!")
		return
	end
	player:SetAttribute("Slot", slot)
	refreshHand(player)
end

-- Adds a weapon to the player's collection and equips it.
function LoadoutService.GiveWeapon(player: Player, weaponId: string)
	local profile = DataService.Get(player)
	if profile and Combat.Weapons[weaponId] then
		profile.Data.OwnedWeapons[weaponId] = true
		LoadoutService.EquipWeapon(player, weaponId)
	end
end

function LoadoutService.EquipWeapon(player: Player, weaponId: string)
	local profile = DataService.Get(player)
	if not profile or not profile.Data.OwnedWeapons[weaponId] then
		return
	end
	profile.Data.Weapon = weaponId
	player:SetAttribute("Weapon", weaponId)
	LoadoutService.Select(player, "Weapon")
end

function LoadoutService.OwnsWeapon(player: Player, weaponId: string): boolean
	local profile = DataService.Get(player)
	return profile ~= nil and profile.Data.OwnedWeapons[weaponId] == true
end

function LoadoutService.Start()
	DataService.OnLoaded(function(player, profile)
		player:SetAttribute("Style", profile.Data.Style)
		player:SetAttribute("Weapon", profile.Data.Weapon)
		player:SetAttribute("Slot", "Style")
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("RightHand", 5)
			refreshHand(player)
		end)
	end)
	Remotes.SelectSlot.OnServerEvent:Connect(function(player, slot)
		if type(slot) == "string" then
			LoadoutService.Select(player, slot)
		end
	end)
end

return LoadoutService
