-- The Gem Merchant: stands near Elder Bram and sells gems for gold.
-- Buying a gem eats it straight away (replacing the one you had).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Gems = require(ReplicatedStorage.Shared.Config.Gems)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local GemService = require(script.Parent.GemService)
local LevelingService = require(script.Parent.LevelingService)
local NpcBuilder = require(script.Parent.NpcBuilder)
local Props = require(script.Parent.Props)

local SHOP_DISTANCE = 14

local MerchantService = {}

local merchantModel: Model? = nil

local function shopFor(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local items = {}
	for _, gemId in Gems.Merchant.Stock do
		local gem = Gems.List[gemId]
		local moves = {}
		for _, key in { "Z", "X", "C" } do
			local move = gem.Moves[key]
			if move then
				table.insert(moves, { Key = key, Name = move.Name, Level = move.Level })
			end
		end
		table.insert(items, {
			Id = gemId,
			Name = gem.DisplayName,
			Rarity = gem.Rarity,
			Color = gem.Color,
			Price = gem.Price,
			Moves = moves,
			Owned = profile.Data.Gem == gemId,
		})
	end
	return {
		Name = Gems.Merchant.DisplayName,
		Greeting = Gems.Merchant.Greeting,
		Gold = profile.Data.Gold,
		CurrentGem = profile.Data.Gem,
		Items = items,
	}
end

local function onAction(player: Player, action: any, gemId: any)
	if action ~= "Buy" or type(gemId) ~= "string" then
		return
	end
	local profile = DataService.Get(player)
	local gem = Gems.List[gemId]
	if not profile or not gem or not table.find(Gems.Merchant.Stock, gemId) then
		return
	end
	if not NpcBuilder.IsNear(player, merchantModel, SHOP_DISTANCE + 4) then
		return
	end
	if profile.Data.Gem == gemId then
		Remotes.Notify:FireClient(player, "You already have the " .. gem.DisplayName)
	elseif profile.Data.Gold < gem.Price then
		Remotes.Notify:FireClient(player, "Not enough gold")
	else
		LevelingService.AddGold(player, -gem.Price)
		GemService.SetGem(player, gemId)
		Remotes.Notify:FireClient(player, ("You ate the %s! Press Z to use it."):format(gem.DisplayName))
	end
	Remotes.ShopDialog:FireClient(player, shopFor(player))
end

function MerchantService.Start()
	local folder = Instance.new("Folder")
	folder.Name = Gems.Merchant.DisplayName
	folder.Parent = workspace

	local model, position = NpcBuilder.Spawn({
		Model = "GemMerchant",
		DisplayName = Gems.Merchant.DisplayName,
		Position = Gems.Merchant.Position,
		Parent = folder,
		StandInColor = Color3.fromRGB(92, 46, 107),
		PromptText = "Shop",
		PromptDistance = SHOP_DISTANCE,
		OnPrompt = function(player)
			Remotes.ShopDialog:FireClient(player, shopFor(player))
		end,
	})
	model:SetAttribute("ShopDistance", SHOP_DISTANCE)
	merchantModel = model

	local facing = model:GetPivot().LookVector
	local side = facing:Cross(Vector3.yAxis)
	Props.Place("Crate", position + side * 3.5 + facing * 0.5, facing, folder, 0.7)
	Props.Place("Barrel", position - side * 3.2, nil, folder, 0.8)

	Remotes.ShopAction.OnServerEvent:Connect(onAction)
end

return MerchantService
