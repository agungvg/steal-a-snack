-- Steal a Snack: Spawner.
-- Runs the central conveyor. New snack characters roll a rarity, a
-- character of that rarity and a mutation, then walk the belt from west
-- to east. Click one (or buy it from the HUD) and, if you can afford it
-- and have a free slot, it walks off to your base and starts earning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)

local Spawner = {}

local walkers = {}
local uidCounter = 0
local running = false

local function nextUid()
	uidCounter += 1
	return "walker_" .. tostring(uidCounter) .. "_" .. tostring(math.random(1000, 9999))
end

local function rollBrainrot()
	local rarity = Config.rollRarity()
	local pool = Config.getByRarity(rarity)
	local pick = pool[math.random(1, #pool)]
	local mutation = Config.rollMutation()
	return pick, mutation
end

function Spawner.spawnOne()
	if #walkers >= Config.MAX_WALKERS then
		return nil
	end
	local pick, mutation = rollBrainrot()
	local uid = nextUid()
	local size = pick.size

	local model = Instance.new("Model")
	model.Name = pick.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(size, size, size)
	body.Color = mutation.color ~= Color3.fromRGB(255, 255, 255) and mutation.color or pick.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = Vector3.new(Config.CONVEYOR_START_X, Config.CONVEYOR_Y + size * 0.5, Config.CONVEYOR_Z)
	body.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(160, 64)
	billboard.StudsOffset = Vector3.new(0, size * 0.9, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = pick.name
		.. "\n"
		.. pick.rarity
		.. (mutation.name ~= "None" and (" " .. mutation.name) or "")
		.. "\n$" .. tostring(pick.rate * mutation.multiplier) .. "/s  -  $" .. tostring(pick.price)
	label.Parent = billboard

	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = 32
	clicker.Parent = body
	clicker.MouseClick:Connect(function(player)
		Spawner.tryBuy(player, uid)
	end)

	model.PrimaryPart = body
	model.Parent = Workspace

	local walker = {
		uid = uid,
		model = model,
		pick = pick,
		mutation = mutation,
		price = pick.price,
		rate = pick.rate * mutation.multiplier,
		x = Config.CONVEYOR_START_X,
	}
	table.insert(walkers, walker)
	return walker
end

function Spawner.findWalker(uid)
	for index, walker in ipairs(walkers) do
		if walker.uid == uid then
			return walker, index
		end
	end
	return nil, nil
end

function Spawner.removeWalker(uid)
	local walker, index = Spawner.findWalker(uid)
	if walker then
		walker.model:Destroy()
		table.remove(walkers, index)
		return walker
	end
	return nil
end

-- Called by the ClickDetector and by the BuyBrainrot RemoteEvent.
-- Checks cash and free slots first, and only then takes the walker off
-- the belt, so a failed buy never eats the snack. Returns true plus a
-- message for the buyer.
function Spawner.tryBuy(player, uid)
	local data = State.get(player)
	if not data then
		return false, "No player state yet."
	end
	local walker = Spawner.findWalker(uid)
	if not walker then
		return false, "That snack already walked away."
	end
	if data.cash < walker.price then
		return false, "Not enough cash for " .. walker.pick.name .. "."
	end
	if not Bases.getFreeSlot(data) then
		return false, "Your base is full. Rebirth to keep climbing."
	end
	Spawner.removeWalker(uid)
	data.cash -= walker.price
	local entry = {
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
						body.Position = Vector3.new(walker.x, Config.CONVEYOR_Y + walker.pick.size * 0.5, Config.CONVEYOR_Z)
					end
				end
			end
		end
	end)
end

return Spawner
