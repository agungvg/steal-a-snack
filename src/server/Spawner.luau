-- Steal a Snack: Spawner.
-- Runs the central conveyor. New snack characters roll a rarity, a
-- character of that rarity and a mutation, then walk the belt from west
-- to east. Click one (or buy it from the HUD) and, if you can afford it
-- and have a free slot, it walks off to your base and starts earning.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)
local CharacterFactory = require(script.Parent.CharacterFactory)
local Effects = require(script.Parent.Effects)
local RateLimit = require(script.Parent.RateLimit)

local Spawner = {}

type Walker = {
	uid: string,
	model: Model,
	pick: Config.Brainrot,
	mutation: Config.Mutation,
	price: number,
	rate: number,
	x: number,
	baseY: number,
	phase: number,
	eyes: { BasePart },
	disc: BasePart,
}

local walkers = {} :: { Walker }
local uidCounter = 0
local running = false

Spawner.onBought = nil :: ((Player) -> ())?
Spawner.onRareSpawn = nil :: ((string) -> ())?

local function nextUid(): string
	uidCounter += 1
	return "walker_" .. tostring(uidCounter) .. "_" .. tostring(math.random(1000, 9999))
end

local function rollBrainrot(): (Config.Brainrot, Config.Mutation)
	local rarity = Config.rollRarity()
	local pool = Config.getByRarity(rarity)
	local pick = pool[math.random(1, #pool)]
	local mutation = Config.rollMutation()
	return pick, mutation
end

-- The buyer's live position, or nil when they have no character, no
-- root part, or are dead. Every distance-gated action goes through
-- here, so a dead or absent character can never buy or steal.
local function playerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

function Spawner.spawnOne(): Walker?
	if #walkers >= Config.MAX_WALKERS then
		return nil
	end
	local pick, mutation = rollBrainrot()
	local uid = nextUid()
	local size = pick.size
	local spawnPos = Vector3.new(Config.CONVEYOR_START_X, Config.CONVEYOR_Y + size * 0.5, Config.CONVEYOR_Z)

	local model, body, eyes, disc = CharacterFactory.build({
		name = pick.name,
		color = mutation.color ~= Color3.fromRGB(255, 255, 255) and mutation.color or pick.color,
		size = size,
		position = spawnPos,
		labelText = pick.name
			.. "\n"
			.. pick.rarity
			.. (mutation.name ~= "None" and (" " .. mutation.name) or "")
			.. "\n$" .. tostring(pick.rate * mutation.multiplier) .. "/s  -  $" .. tostring(pick.price),
		forward = Vector3.new(1, 0, 0),
		lateral = Vector3.new(0, 0, 1),
		billboardSize = UDim2.fromOffset(160, 64),
		clickDistance = 32,
		onClick = function(player: Player)
			Spawner.tryBuy(player, uid)
		end,
		parent = Workspace,
	})

	local walker: Walker = {
		uid = uid,
		model = model,
		pick = pick,
		mutation = mutation,
		price = pick.price,
		rate = pick.rate * mutation.multiplier,
		x = Config.CONVEYOR_START_X,
		baseY = Config.CONVEYOR_Y + size * 0.5,
		phase = math.random() * math.pi * 2,
		eyes = eyes,
		disc = disc,
	}
	table.insert(walkers, walker)

	-- The signature moment: a Legendary or Mythic on the belt is
	-- announced to the whole server with a burst at the spawn, so the
	-- rare spawn is a visible event, not just another label.
	if pick.rarity == "Legendary" or pick.rarity == "Mythic" then
		Effects.burst(body.Position, Config.RARITY_COLORS[pick.rarity])
		if Spawner.onRareSpawn then
			Spawner.onRareSpawn("RARE SPAWN! " .. pick.rarity .. " " .. pick.name .. " is on the belt!")
		end
	end

	return walker
end

function Spawner.findWalker(uid: string): (Walker?, number?)
	for index, walker in ipairs(walkers) do
		if walker.uid == uid then
			return walker, index
		end
	end
	return nil, nil
end

function Spawner.removeWalker(uid: string): Walker?
	local walker, index = Spawner.findWalker(uid)
	if walker then
		walker.model:Destroy()
		table.remove(walkers, index)
		return walker
	end
	return nil
end

-- Called by the ClickDetector on the walker. The server decides: the
-- uid must be a string, the buyer must be rate-limited, alive, close
-- to the walker, solvent, and holding a base with a free slot. Checks
-- run before anything is taken, so a failed buy never eats the snack.
-- Returns true plus a message for the buyer.
function Spawner.tryBuy(player: Player, uid: any): (boolean, string)
	if typeof(uid) ~= "string" then
		return false, "Bad buy request."
	end
	if not RateLimit.check(player, "buy") then
		return false, "Slow down! Too many clicks."
	end
	local data = State.get(player)
	if not data then
		return false, "No player state yet."
	end
	if data.baseIndex == 0 then
		return false, "No free base right now. Wait for a plot to open."
	end
	local walker = Spawner.findWalker(uid)
	if not walker then
		return false, "That snack already walked away."
	end
	local where = playerPosition(player)
	if not where then
		return false, "You need to be alive and in the world to buy."
	end
	local walkerPos = Vector3.new(walker.x, walker.baseY, Config.CONVEYOR_Z)
	if (where - walkerPos).Magnitude > Config.ACTION_RANGE then
		return false, "Too far from that snack. Walk up to the belt!"
	end
	if data.cash < walker.price then
		return false, "Not enough cash for " .. walker.pick.name .. "."
	end
	if not Bases.getFreeSlot(data) then
		return false, "Your base is full. Rebirth to keep climbing."
	end
	Spawner.removeWalker(uid)
	data.cash -= walker.price
	local entry: State.OwnedEntry = {
		uid = "owned_" .. tostring(math.random(100000, 999999)) .. "_" .. tostring(os.clock()),
		id = walker.pick.id,
		name = walker.pick.name,
		rarity = walker.pick.rarity,
		rate = walker.pick.rate,
		multiplier = walker.mutation.multiplier,
		mutation = walker.mutation.name,
		color = walker.pick.color,
		size = walker.pick.size,
		slot = 0,
	}
	Bases.placeOnBase(data, entry)
	State.addOwned(data, entry)
	Effects.burst(Bases.slotPosition(data.baseIndex, entry.slot), entry.color)
	if Spawner.onBought then
		Spawner.onBought(player)
	end
	return true, "Bought " .. entry.name .. " for $" .. tostring(walker.price) .. "!"
end

function Spawner.sweepWalkers()
	for _, walker in ipairs(walkers) do
		walker.model:Destroy()
	end
	table.clear(walkers)
end

function Spawner.start()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while true do
			task.wait(Config.SPAWN_INTERVAL)
			Spawner.spawnOne()
		end
	end)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.05)
			local now = os.clock()
			local dt = now - last
			last = now
			for index = #walkers, 1, -1 do
				local walker = walkers[index]
				walker.x += Config.CONVEYOR_SPEED * dt
				if walker.x >= Config.CONVEYOR_END_X then
					walker.model:Destroy()
					table.remove(walkers, index)
				else
					local body = walker.model.PrimaryPart
					if body then
						-- A little hop as it walks: the bob makes the
						-- belt feel alive instead of sliding statues.
						local hop = math.abs(math.sin(now * 5 + walker.phase)) * 0.35
						local pos = Vector3.new(walker.x, walker.baseY + hop, Config.CONVEYOR_Z)
						body.Position = pos
						-- The shadow disc rides the belt surface under
						-- the body (Position keeps its flat orientation).
						walker.disc.Position =
							Vector3.new(walker.x, Config.CONVEYOR_Y - 0.4, Config.CONVEYOR_Z)
						local eyeOffset = walker.pick.size * 0.22
						for eyeIndex, eye in ipairs(walker.eyes) do
							local side = eyeIndex == 1 and -1 or 1
							eye.Position = pos
								+ Vector3.new(walker.pick.size * 0.48, walker.pick.size * 0.18, side * eyeOffset)
						end
					end
				end
			end
		end
	end)
end

return Spawner
