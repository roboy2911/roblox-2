-- All RemoteEvents in one place. The server creates them; clients wait for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()

local folder: Folder
if IS_SERVER then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function remote(name: string): RemoteEvent
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	Attack = remote("Attack"), -- client -> server: player clicked (with aim direction)
	Swing = remote("Swing"), -- server -> all: someone swung (to play their animation)
	HitEffect = remote("HitEffect"), -- server -> all: a hit landed (effects, damage numbers)
	EnemyFx = remote("EnemyFx"), -- server -> all: boss attack effects (slam landing)
	PlayerHit = remote("PlayerHit"), -- server -> player: an enemy hit you
	Reward = remote("Reward"), -- server -> player: XP and gold earned (floating text)
	QuestDialog = remote("QuestDialog"), -- server -> player: open a quest giver's dialog
	QuestAction = remote("QuestAction"), -- client -> server: accept or abandon a quest
	SelectSlot = remote("SelectSlot"), -- client -> server: pressed 1/2/3
	UseAbility = remote("UseAbility"), -- client -> server: Z/X/C pressed (with aim)
	AbilityFx = remote("AbilityFx"), -- server -> all: show an ability (fireball, dash, ring, gem eaten)
	ShopDialog = remote("ShopDialog"), -- server -> player: open a shop
	ShopAction = remote("ShopAction"), -- client -> server: buy something
	LevelUp = remote("LevelUp"), -- server -> player: new level reached
	Notify = remote("Notify"), -- server -> player: short message on screen
}
