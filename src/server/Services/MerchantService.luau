-- Shops in Millbrook:
--   Gem Merchant Zara: gems (buying one eats it, replacing yours)
--   Blacksmith Torvin: weapons (buy once, then equip any you own for free)
-- Each shop describes its items generically for the shop window: name,
-- info lines, price and what the button says.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local GemService = require(script.Parent.GemService)
local LevelingService = require(script.Parent.LevelingService)
local LoadoutService = require(script.Parent.LoadoutService)
local NpcBuilder = require(script.Parent.NpcBuilder)
local Props = require(script.Parent.Props)

local SHOP_DISTANCE = 14

local MerchantService = {}

type Shop = {
	Config: any,
	Model: Model?,
	Items: (profile: any) -> { any },
	Act: (player: Player, profile: any, itemId: string) -> (),
}

local shops: { [string]: Shop } = {}

local function moveLines(moves): { string }
	local lines = {}
	for _, key in { "Z", "X", "C" } do
		local move = moves[key]
		if move then
			table.insert(lines, if move.Level > 1
				then ("%s  %s  (Lv. %d)"):format(key, move.Name, move.Level)
				else ("%s  %s"):format(key, move.Name))
		end
	end
	return lines
end

local function buyButton(profile, price: number, owned: boolean, ownedText: string, buyText: string)
	if owned then
		return { Text = ownedText, Enabled = false }
	elseif profile.Data.Gold < price then
		return { Text = "Not enough gold", Enabled = false }
	end
	return { Text = buyText, Enabled = true }
end

-- Gem Merchant ---------------------------------------------------------------

shops.Gems = {
	Config = Gems.Merchant,
	Items = function(profile)
		local items = {}
		local current = Gems.List[profile.Data.Gem]
		for _, gemId in Gems.Merchant.Stock do
			local gem = Gems.List[gemId]
			local owned = profile.Data.Gem == gemId
			table.insert(items, {
				Id = gemId,
				Name = gem.DisplayName,
				Subtitle = gem.Rarity,
				Color = gem.Color,
				Lines = moveLines(gem.Moves),
				Price = gem.Price,
				Note = if current and not owned then "Replaces your " .. current.DisplayName else nil,
				Button = buyButton(profile, gem.Price, owned, "Owned", "Buy & Eat"),
			})
		end
		return items
	end,
	Act = function(player, profile, gemId)
		local gem = Gems.List[gemId]
		if not gem or not table.find(Gems.Merchant.Stock, gemId) or profile.Data.Gem == gemId then
			return
		end
		if profile.Data.Gold < gem.Price then
			Remotes.Notify:FireClient(player, "Not enough gold")
			return
		end
		LevelingService.AddGold(player, -gem.Price)
		GemService.SetGem(player, gemId)
		Remotes.Notify:FireClient(player, ("You ate the %s! Press 3, then Z to use it."):format(gem.DisplayName))
	end,
}

-- Blacksmith -------------------------------------------------------------------

shops.Weapons = {
	Config = Combat.Blacksmith,
	Items = function(profile)
		local items = {}
		for _, weaponId in Combat.Blacksmith.Stock do
			local weapon = Combat.Weapons[weaponId]
			local owned = profile.Data.OwnedWeapons[weaponId] == true
			local equipped = profile.Data.Weapon == weaponId
			local lines = { weapon.Description, "Click  3-hit combo" }
			for _, line in moveLines(weapon.Moves) do
				table.insert(lines, line)
			end
			local button
			if equipped then
				button = { Text = "Equipped", Enabled = false }
			elseif owned then
				button = { Text = "Equip", Enabled = true }
			else
				button = buyButton(profile, weapon.Price, false, "", "Buy")
			end
			table.insert(items, {
				Id = weaponId,
				Name = weapon.DisplayName,
				Subtitle = "Weapon",
				Color = Color3.fromRGB(205, 210, 220),
				Lines = lines,
				Price = if owned then nil else weapon.Price,
				Button = button,
			})
		end
		return items
	end,
	Act = function(player, profile, weaponId)
		local weapon = Combat.Weapons[weaponId]
		if not weapon or not table.find(Combat.Blacksmith.Stock, weaponId) then
			return
		end
		if LoadoutService.OwnsWeapon(player, weaponId) then
			LoadoutService.EquipWeapon(player, weaponId)
			return
		end
		if profile.Data.Gold < weapon.Price then
			Remotes.Notify:FireClient(player, "Not enough gold")
			return
		end
		LevelingService.AddGold(player, -weapon.Price)
		LoadoutService.GiveWeapon(player, weaponId)
		Remotes.Notify:FireClient(player, ("You bought the %s! Press 2 to hold it."):format(weapon.DisplayName))
	end,
}

-- Shared -------------------------------------------------------------------------

local function windowFor(player: Player, shopId: string)
	local shop = shops[shopId]
	local profile = DataService.Get(player)
	if not shop or not profile then
		return nil
	end
	return {
		ShopId = shopId,
		Name = shop.Config.DisplayName,
		Greeting = shop.Config.Greeting,
		Position = shop.Config.Position,
		Gold = profile.Data.Gold,
		Items = shop.Items(profile),
	}
end

local function onAction(player: Player, shopId: any, itemId: any)
	if type(shopId) ~= "string" or type(itemId) ~= "string" then
		return
	end
	local shop = shops[shopId]
	local profile = DataService.Get(player)
	if not shop or not profile or not NpcBuilder.IsNear(player, shop.Model, SHOP_DISTANCE + 4) then
		return
	end
	shop.Act(player, profile, itemId)
	Remotes.ShopDialog:FireClient(player, windowFor(player, shopId))
end

local function spawnShop(shopId: string, modelName: string, standIn: Color3, decorate: (Instance, Vector3, Vector3) -> ())
	local shop = shops[shopId]
	local folder = Instance.new("Folder")
	folder.Name = shop.Config.DisplayName
	folder.Parent = workspace
	local model, position = NpcBuilder.Spawn({
		Model = modelName,
		DisplayName = shop.Config.DisplayName,
		Position = shop.Config.Position,
		Parent = folder,
		StandInColor = standIn,
		PromptText = "Shop",
		PromptDistance = SHOP_DISTANCE,
		OnPrompt = function(player)
			Remotes.ShopDialog:FireClient(player, windowFor(player, shopId))
		end,
	})
	shop.Model = model
	decorate(folder, position, model:GetPivot().LookVector)
end

function MerchantService.Start()
	spawnShop("Gems", "GemMerchant", Color3.fromRGB(92, 46, 107), function(folder, position, facing)
		local side = facing:Cross(Vector3.yAxis)
		Props.Place("Crate", position + side * 3.5 + facing * 0.5, facing, folder, 0.7)
		Props.Place("Barrel", position - side * 3.2, nil, folder, 0.8)
	end)
	spawnShop("Weapons", "Blacksmith", Color3.fromRGB(120, 90, 60), function(folder, position, facing)
		local side = facing:Cross(Vector3.yAxis)
		Props.Place("Anvil", position + side * 3.5 + facing * 1.5, side, folder)
		Props.Place("Barrel", position - side * 3.5, nil, folder, 0.8)
		Props.Place("Crate", position - side * 4 - facing * 2.5, facing, folder, 0.8)
	end)
	Remotes.ShopAction.OnServerEvent:Connect(onAction)
end

return MerchantService
