-- Quest givers and quest progress.
--
-- Talk to a giver (E) to see their quests. Accept one, defeat the enemies,
-- and it completes on its own: XP and gold are paid straight away. One
-- active quest at a time; it's saved, so it survives rejoining.
-- The active quest is copied onto the player as attributes for the tracker:
--   QuestId, QuestTitle, QuestProgress, QuestCount, QuestEnemy

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Enemies = require(ReplicatedStorage.Shared.Config.Enemies)
local Quests = require(ReplicatedStorage.Shared.Config.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AssetService = require(script.Parent.AssetService)
local DataService = require(script.Parent.DataService)
local LevelingService = require(script.Parent.LevelingService)
local Props = require(script.Parent.Props)

local GIVER_TAG = "QuestGiver"
local GIVER_HEIGHT = 5.8

local QuestService = {}

local giverModels: { [string]: Model } = {}

local function enemyName(enemyType: string): string
	local config = Enemies.Types[enemyType]
	return if config then config.DisplayName else enemyType
end

local function sync(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local active = profile.Data.Quest
	local quest = Quests.List[active.Id]
	if quest then
		player:SetAttribute("QuestId", active.Id)
		player:SetAttribute("QuestTitle", quest.Title)
		player:SetAttribute("QuestProgress", active.Progress)
		player:SetAttribute("QuestCount", quest.Count)
		player:SetAttribute("QuestEnemy", enemyName(quest.Enemy))
	else
		player:SetAttribute("QuestId", "")
		player:SetAttribute("QuestTitle", nil)
		player:SetAttribute("QuestProgress", nil)
		player:SetAttribute("QuestCount", nil)
		player:SetAttribute("QuestEnemy", nil)
	end
end

-- What the dialog shows: the giver's quests and the player's current quest.
local function dialogFor(player: Player, giverId: string)
	local giver = Quests.Givers[giverId]
	local profile = DataService.Get(player)
	if not giver or not profile then
		return nil
	end
	local list = {}
	for _, questId in giver.Quests do
		local quest = Quests.List[questId]
		table.insert(list, {
			Id = questId,
			Title = quest.Title,
			Description = quest.Description,
			Count = quest.Count,
			Enemy = enemyName(quest.Enemy),
			MinLevel = quest.MinLevel,
			XP = quest.XP,
			Gold = quest.Gold,
			Locked = profile.Data.Level < quest.MinLevel,
		})
	end
	local active = profile.Data.Quest
	local activeQuest = Quests.List[active.Id]
	return {
		GiverId = giverId,
		Name = giver.DisplayName,
		Greeting = giver.Greeting,
		Quests = list,
		Active = activeQuest and {
			Id = active.Id,
			Title = activeQuest.Title,
			Progress = active.Progress,
			Count = activeQuest.Count,
			Enemy = enemyName(activeQuest.Enemy),
		},
	}
end

local function isNearGiver(player: Player, giverId: string): boolean
	local model = giverModels[giverId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return model ~= nil and root ~= nil
		and (root.Position - model:GetPivot().Position).Magnitude <= Quests.TalkDistance + 4
end

local function onAction(player: Player, action: any, giverId: any, questId: any)
	local profile = DataService.Get(player)
	if not profile or type(action) ~= "string" then
		return
	end
	local data = profile.Data

	if action == "Abandon" then
		if data.Quest.Id ~= "" then
			data.Quest = { Id = "", Progress = 0 }
			sync(player)
			Remotes.Notify:FireClient(player, "Quest abandoned")
		end
	elseif action == "Accept" and type(giverId) == "string" and type(questId) == "string" then
		local giver = Quests.Givers[giverId]
		local quest = Quests.List[questId]
		if not giver or not quest or not table.find(giver.Quests, questId) then
			return
		end
		if data.Quest.Id ~= "" or data.Level < quest.MinLevel or not isNearGiver(player, giverId) then
			return
		end
		data.Quest = { Id = questId, Progress = 0 }
		sync(player)
		Remotes.Notify:FireClient(player, "Quest accepted: " .. quest.Title)
	end

	-- Refresh the open dialog.
	if type(giverId) == "string" and Quests.Givers[giverId] then
		Remotes.QuestDialog:FireClient(player, dialogFor(player, giverId))
	end
end

-- Refreshes the tracker attributes (e.g. after a data reset).
QuestService.Sync = sync

-- Called by EnemyService when a player earns a kill.
function QuestService.OnEnemyKilled(player: Player, enemyType: string?)
	local profile = DataService.Get(player)
	if not profile or not enemyType then
		return
	end
	local active = profile.Data.Quest
	local quest = Quests.List[active.Id]
	if not quest or quest.Enemy ~= enemyType then
		return
	end
	active.Progress += 1
	if active.Progress < quest.Count then
		sync(player)
		return
	end

	-- Done: pay out and clear.
	profile.Data.Quest = { Id = "", Progress = 0 }
	sync(player)
	LevelingService.AddXP(player, quest.XP)
	LevelingService.AddGold(player, quest.Gold)
	Remotes.Notify:FireClient(player, "Quest complete: " .. quest.Title)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Remotes.Reward:FireClient(player, root.Position + Vector3.new(0, 2, 0), quest.XP, quest.Gold)
	end
end

-- Builds the giver: textured model, a head that can turn, and a talk prompt.
local function spawnGiver(giverId: string, giver)
	local folder = Instance.new("Folder")
	folder.Name = giver.DisplayName
	folder.Parent = workspace

	local y = Props.GroundY(giver.Position)
	local position = Vector3.new(giver.Position.X, y, giver.Position.Z)
	local toSpawn = (Vector3.zero - position) * Vector3.new(1, 0, 1)
	toSpawn = if toSpawn.Magnitude > 0.01 then toSpawn.Unit else -Vector3.zAxis

	local model = AssetService.Model("QuestGiver")
	if not model then
		-- Stand-in: robe block and a head.
		model = Instance.new("Model")
		local robe = Instance.new("Part")
		robe.Name = "Body"
		robe.Size = Vector3.new(2, 4.6, 1.4)
		robe.CFrame = CFrame.new(0, 2.3, 0)
		robe.Color = Color3.fromRGB(56, 92, 51)
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
	end
	model.Name = giver.DisplayName
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * GIVER_HEIGHT / size.Y)

	-- Neck joint so clients can turn the head toward players.
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

	model:PivotTo(CFrame.lookAt(position, position + toSpawn))
	model:SetAttribute("GiverId", giverId)
	model:SetAttribute("BarHeight", GIVER_HEIGHT + 1)
	model.Parent = folder
	CollectionService:AddTag(model, GIVER_TAG)
	giverModels[giverId] = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = giver.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Quests.TalkDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = body or model:FindFirstChildWhichIsA("BasePart")
	prompt.Triggered:Connect(function(player)
		Remotes.QuestDialog:FireClient(player, dialogFor(player, giverId))
	end)

	-- A little market corner around the giver.
	local side = toSpawn:Cross(Vector3.yAxis)
	Props.Place("Stall", position + side * 7 - toSpawn * 2, toSpawn, folder)
	Props.Place("Barrel", position - side * 4.5 - toSpawn * 1.5, nil, folder)
	Props.Place("Crate", position - side * 6.5 - toSpawn * 2.5, toSpawn, folder)
	Props.Sign("Millbrook", position + toSpawn * 9 - side * 9, toSpawn, folder)
end

function QuestService.Start()
	for giverId, giver in Quests.Givers do
		spawnGiver(giverId, giver)
	end
	Remotes.QuestAction.OnServerEvent:Connect(onAction)
	DataService.OnLoaded(function(player)
		sync(player)
	end)
end

return QuestService
