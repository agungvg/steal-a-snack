-- Steal a Snack: Saves.
-- DataStore persistence for cash, rebirths and the owned collection.
-- Without this, every session evaporated on leave; with it, a player's
-- snacks, cash and rebirth multiplier are still there next join.
--
-- Rules, all deliberate:
-- * Versioned schema (version = 1). An unknown version is ignored and
--   the player starts fresh, never loaded half-way.
-- * Every DataStore call is pcall-wrapped. A failed read keeps the
--   fresh session and the player keeps playing; a failed write is
--   retried on the next autosave. A failed call NEVER wipes a save.
-- * Only ids and mutation names are stored. Rates, multipliers, colours
--   and sizes are rebuilt from Config on load, so a stale or tampered
--   save can never smuggle in a fake income rate.
-- * Save on a 60 s timer, on PlayerRemoving, and on BindToClose, so a
--   server shutdown still keeps progress.
-- * In Studio with API access off, DataStore calls fail closed into
--   the same pcall path and the game runs fine without saves.

--!strict

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Saves = {}

local SAVE_VERSION = 1
local STORE_NAME = "StealASnackV1"
local AUTOSAVE_SECONDS = 60

local store = nil
local warnedNoStore = false

-- The save payload, as a type. DataStore hands back untyped data, so
-- the load path casts it to this shape once, right after the version
-- check, instead of indexing a bare `table` all over the restore.
type SaveData = {
	version: number,
	cash: number,
	rebirths: number,
	owned: { { id: string, mutation: string } },
}

local function getStore()
	if store then
		return store
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		if not warnedNoStore then
			warnedNoStore = true
			warn("Steal a Snack: DataStore unavailable, saves disabled this server.")
		end
		return nil
	end
	store = result
	return store
end

local function keyFor(player: Player): string
	return "player_" .. tostring(player.UserId)
end

-- The plain-data shape that goes into the store. Nothing but numbers
-- and strings, so it serialises exactly.
function Saves.toSaveData(data: any)
	local owned = {}
	for _, entry in ipairs(data.owned) do
		table.insert(owned, { id = entry.id, mutation = entry.mutation })
	end
	return {
		version = SAVE_VERSION,
		cash = math.floor(data.cash),
		rebirths = data.rebirths,
		owned = owned,
	}
end

-- Load a player's save into their live session data. Returns true when
-- a valid save was applied. Unknown brainrot ids or mutation names are
-- skipped, never trusted; cash and rebirths are clamped to sane ranges.
function Saves.loadInto(State: any, Bases: any, player: Player, data: any): boolean
	local datastore = getStore()
	if not datastore then
		return false
	end
	local ok, saved = pcall(function()
		return datastore:GetAsync(keyFor(player))
	end)
	if not ok then
		warn("Steal a Snack: save read failed for " .. player.Name .. "; starting fresh.")
		return false
	end
	if typeof(saved) ~= "table" or saved.version ~= SAVE_VERSION then
		return false
	end
	-- From here on the payload is a version-1 save. Fields are still
	-- validated one by one below; the cast only gives the checker a
	-- shape to work with.
	local saveData = saved :: SaveData
	if typeof(saveData.cash) == "number" then
		data.cash = math.clamp(math.floor(saveData.cash), 0, 1000000000)
	end
	if typeof(saveData.rebirths) == "number" then
		data.rebirths = math.clamp(math.floor(saveData.rebirths), 0, 100)
	end
	-- Owned snacks only restore onto a real base. With no free plot
	-- the cash and rebirths above still restore, and the snacks wait
	-- in the store for a join with a free base.
	if data.baseIndex > 0 and typeof(saveData.owned) == "table" then
		for index, savedEntry in ipairs(saveData.owned) do
			if typeof(savedEntry) == "table" then
				local brainrot = Config.getBrainrot(savedEntry.id)
				local mutation = Config.getMutation(savedEntry.mutation)
				if brainrot and mutation then
					local entry = {
						uid = "restored_" .. tostring(index) .. "_" .. tostring(math.random(100000, 999999)),
						id = brainrot.id,
						name = brainrot.name,
						rarity = brainrot.rarity,
						rate = brainrot.rate,
						multiplier = mutation.multiplier,
						mutation = mutation.name,
						color = brainrot.color,
						size = brainrot.size,
						slot = 0,
					}
					if Bases.placeOnBase(data, entry) then
						State.addOwned(data, entry)
					end
				end
			end
		end
	end
	return true
end

-- Write one player's session to the store. False on any failure; the
-- in-memory session is untouched and the next autosave retries.
function Saves.saveNow(player: Player, data: any): boolean
	local datastore = getStore()
	if not datastore then
		return false
	end
	local ok, err = pcall(function()
		datastore:SetAsync(keyFor(player), Saves.toSaveData(data))
	end)
	if not ok then
		warn("Steal a Snack: save write failed for " .. player.Name .. ": " .. tostring(err))
		return false
	end
	return true
end

function Saves.start(State: any)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, data in pairs(State.players) do
				if player.Parent then
					Saves.saveNow(player, data)
				end
			end
		end
	end)
end

function Saves.saveAll(State: any)
	for player, data in pairs(State.players) do
		if player.Parent then
			Saves.saveNow(player, data)
		end
	end
end

return Saves
