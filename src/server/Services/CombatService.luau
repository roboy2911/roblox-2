-- Handles clicks from players. The server owns the combo counter, the
-- cooldowns and the hit check, so clients can't spam or hit from far away.
-- Damage lands a moment after the click, when the fist connects in the
-- animation, and every client is told so they can show the hit effects.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local Damageable = require(script.Parent.Damageable)

-- Allow clicks to arrive a little early to cover network jitter.
local LATENCY_GRACE = 0.08
-- Extra reach for big targets, measured from their pivot.
local DEFAULT_HIT_RADIUS = 1.5

type ComboState = { Index: number, LastSwing: number, ReadyAt: number }

local CombatService = {}

local states: { [Player]: ComboState } = {}

-- The direction the client says it's punching, flattened. Falls back to the
-- way the character faces. A cheater can only pick one direction, and the
-- range check still applies, so trusting it is safe.
local function aimDirection(rootPart: BasePart, aim: any): Vector3
	if typeof(aim) == "Vector3" then
		local flat = aim * Vector3.new(1, 0, 1)
		if flat.Magnitude > 0.01 and flat.Magnitude == flat.Magnitude then -- also rejects NaN
			return flat.Unit
		end
	end
	local look = rootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	return if look.Magnitude > 0.01 then look.Unit else Vector3.zAxis
end

local function findTargets(origin: Vector3, look: Vector3, style): { Model }
	local hits = {}
	for _, model in CollectionService:GetTagged(Damageable.Tag) do
		if not model:IsA("Model") or not model:IsDescendantOf(workspace) or not Damageable.IsAlive(model) then
			continue
		end
		local offset = (model:GetPivot().Position - origin) * Vector3.new(1, 0, 1)
		local distance = offset.Magnitude
		local reach = style.Range + (model:GetAttribute("HitRadius") or DEFAULT_HIT_RADIUS)
		if distance > reach then
			continue
		end
		if distance < 0.5 or look:Dot(offset.Unit) >= style.HitArc then
			table.insert(hits, model)
		end
	end
	return hits
end

-- Runs when the fist lands (a moment after the click), using where the
-- player is at that moment.
local function resolveHit(player: Player, style, move, aim: any)
	local profile = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not profile or not humanoid or humanoid.Health <= 0 or not rootPart then
		return
	end

	local statPoints = profile.Data.Stats[style.Stat] or 0
	local look = aimDirection(rootPart, aim)
	for _, target in findTargets(rootPart.Position, look, style) do
		local damage = Combat.CalculateDamage(move.Damage, statPoints, target:GetAttribute("Defense") or 0)
		local dealt, killed = Damageable.ApplyDamage(target, damage, player, { Heavy = move.Heavy == true })
		if dealt > 0 then
			Damageable.Stun(target, style.Stun)
			Remotes.HitEffect:FireAllClients(player, target, dealt, killed, move.Heavy == true)
		end
	end
end

local function onAttack(player: Player, aim: any)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not DataService.Get(player) or not humanoid or humanoid.Health <= 0 then
		return
	end

	local style = Combat.Styles[Combat.DefaultStyle]
	local now = os.clock()
	local state = states[player]
	if not state then
		state = { Index = 0, LastSwing = 0, ReadyAt = 0 }
		states[player] = state
	end
	if now < state.ReadyAt - LATENCY_GRACE then
		return
	end

	if now - state.LastSwing > style.ComboResetTime or state.Index >= #style.Combo then
		state.Index = 0
	end
	state.Index += 1
	state.LastSwing = now
	local isLast = state.Index == #style.Combo
	state.ReadyAt = now + (if isLast then style.ComboEndCooldown else style.SwingCooldown)

	local move = style.Combo[state.Index]
	Remotes.Swing:FireAllClients(player, state.Index)
	task.delay(move.HitDelay or 0, resolveHit, player, style, move, aim)
end

function CombatService.Start()
	Remotes.Attack.OnServerEvent:Connect(onAttack)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
