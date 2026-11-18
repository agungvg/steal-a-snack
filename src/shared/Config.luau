-- Steal a Snack: shared tuning table.
-- One source of truth for the cast, rarities, mutations, prices and
-- timers. Both the server services and the client HUD read from here,
-- so a balance change in this file reaches every system at once.

--!strict

export type Brainrot = {
	id: string,
	name: string,
	rarity: string,
	rate: number,
	price: number,
	color: Color3,
	size: number,
}

export type Mutation = {
	name: string,
	multiplier: number,
	chance: number,
	color: Color3,
}

local Config = {}

Config.START_CASH = 100
Config.CASH_TICK_SECONDS = 1
Config.MAX_SLOTS_PER_BASE = 6
Config.MAX_BASES = 8

Config.REBIRTH_BASE_COST = 25000
Config.REBIRTH_MULTIPLIER_STEP = 0.25

Config.LOCK_DURATION = 20
Config.LOCK_COOLDOWN = 60

-- One successful steal puts the thief on a short cooldown, so a base
-- cannot be machine-gun emptied one click at a time.
Config.STEAL_COOLDOWN = 5

Config.WAVE_PERIOD = 90
Config.WAVE_WARN_SECONDS = 10
Config.WAVE_DURATION = 10

Config.CONVEYOR_SPEED = 6
Config.CONVEYOR_START_X = -64
Config.CONVEYOR_END_X = 64
Config.CONVEYOR_Z = 0
Config.CONVEYOR_Y = 2.5
Config.SPAWN_INTERVAL = 7
Config.MAX_WALKERS = 10

-- How close a player must be to a walker (buy) or a base slot (steal)
-- for the server to accept the action. The ClickDetectors gate this
-- first at 32 studs; the server check is the second, explicit gate, so
-- a forged RemoteEvent or a spoofed click can never act cross-map.
Config.ACTION_RANGE = 40

-- The cast. price is what a brainrot costs on the belt; rate is the
-- cash it earns every second once it is standing on your base.
Config.BRAINROTS = {
	{ id = "soggy_fry", name = "Soggy Fry", rarity = "Common", rate = 1, price = 50, color = Color3.fromRGB(255, 196, 66), size = 3.3 },
	{ id = "noodle_ned", name = "Noodle Ned", rarity = "Common", rate = 2, price = 100, color = Color3.fromRGB(255, 214, 130), size = 3.6 },
	{ id = "dancing_dumpling", name = "Dancing Dumpling", rarity = "Rare", rate = 5, price = 300, color = Color3.fromRGB(255, 240, 200), size = 3.9 },
	{ id = "turbo_taco", name = "Turbo Taco", rarity = "Rare", rate = 8, price = 500, color = Color3.fromRGB(255, 170, 40), size = 4.2 },
	{ id = "lord_lasagna", name = "Lord Lasagna", rarity = "Epic", rate = 15, price = 1500, color = Color3.fromRGB(230, 120, 60), size = 4.5 },
	{ id = "queen_queso", name = "Queen Queso", rarity = "Epic", rate = 20, price = 2500, color = Color3.fromRGB(255, 215, 0), size = 4.8 },
	{ id = "king_kebab", name = "King Kebab", rarity = "Legendary", rate = 40, price = 6000, color = Color3.fromRGB(180, 60, 60), size = 5.1 },
	{ id = "baron_burger", name = "Baron Burger", rarity = "Legendary", rate = 60, price = 10000, color = Color3.fromRGB(150, 90, 40), size = 5.4 },
	{ id = "eternal_ramen", name = "The Eternal Ramen", rarity = "Mythic", rate = 120, price = 25000, color = Color3.fromRGB(255, 80, 80), size = 6.0 },
}

Config.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

Config.RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 60, 120),
} :: { [string]: Color3 }

-- Rarity weights for the conveyor spawn roll. Common shows up most;
-- Mythic is a rare sight on the belt, which is the whole point.
Config.SPAWN_WEIGHTS = {
	Common = 46,
	Rare = 28,
	Epic = 15,
	Legendary = 8,
	Mythic = 3,
} :: { [string]: number }

-- Mutations rolled when a brainrot spawns. multiplier applies to income.
Config.MUTATIONS = {
	{ name = "Rainbow", multiplier = 10, chance = 0.01, color = Color3.fromRGB(255, 100, 220) },
	{ name = "Diamond", multiplier = 5, chance = 0.05, color = Color3.fromRGB(120, 220, 255) },
	{ name = "Golden", multiplier = 2, chance = 0.15, color = Color3.fromRGB(255, 215, 0) },
	{ name = "None", multiplier = 1, chance = 1.0, color = Color3.fromRGB(255, 255, 255) },
}

function Config.getBrainrot(id: string): Brainrot?
	for _, entry in ipairs(Config.BRAINROTS) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Config.getMutation(name: string): Mutation?
	for _, mutation in ipairs(Config.MUTATIONS) do
		if mutation.name == name then
			return mutation
		end
	end
	return nil
end

function Config.getByRarity(rarity: string): { Brainrot }
	local out = {}
	for _, entry in ipairs(Config.BRAINROTS) do
		if entry.rarity == rarity then
			table.insert(out, entry)
		end
	end
	return out
end

function Config.rollMutation(): Mutation
	local roll = math.random()
	for _, mutation in ipairs(Config.MUTATIONS) do
		if roll <= mutation.chance then
			return mutation
		end
	end
	return Config.MUTATIONS[#Config.MUTATIONS]
end

function Config.rollRarity(): string
	local total = 0
	for _, weight in pairs(Config.SPAWN_WEIGHTS) do
		total += weight
	end
	local roll = math.random(total)
	local running = 0
	for _, rarity in ipairs(Config.RARITY_ORDER) do
		running += Config.SPAWN_WEIGHTS[rarity]
		if roll <= running then
			return rarity
		end
	end
	return "Common"
end

function Config.rebirthCost(rebirths: number): number
	return Config.REBIRTH_BASE_COST * (rebirths + 1)
end

function Config.incomeMultiplier(rebirths: number): number
	return 1 + Config.REBIRTH_MULTIPLIER_STEP * rebirths
end

return Config
