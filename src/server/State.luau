-- Steal a Snack: State.
-- The one place all player state lives. Every other server module reads
-- and writes through here, so cash, brainrots, locks and rebirths can
-- never disagree between systems.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local State = {}

State.players = {}
State.takenBases = {}

function State.newPlayer(player)
	local data = {
		cash = Config.START_CASH,
		rebirths = 0,
		baseIndex = 0,
		lockUntil = 0,
		lockCooldownUntil = 0,
		owned = {},
	}
	State.players[player] = data
	return data
end

function State.get(player)
	return State.players[player]
end

function State.remove(player)
	local data = State.players[player]
	if data and data.baseIndex > 0 then
		State.takenBases[data.baseIndex] = nil
	end
	State.players[player] = nil
end

function State.computeIncome(data)
	local total = 0
	for _, entry in ipairs(data.owned) do
		total += entry.rate * entry.multiplier
	end
	return total * Config.incomeMultiplier(data.rebirths)
end

function State.addOwned(data, entry)
	table.insert(data.owned, entry)
end

function State.findOwned(data, uid)
	for index, entry in ipairs(data.owned) do
		if entry.uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

function State.removeOwned(data, uid)
	local _, index = State.findOwned(data, uid)
	if index then
		table.remove(data.owned, index)
		return true
	end
	return false
end

function State.isLocked(data)
	return os.clock() < data.lockUntil
end

function State.lockRemaining(data)
	return math.max(0, data.lockUntil - os.clock())
end

function State.lockCooldownRemaining(data)
	return math.max(0, data.lockCooldownUntil - os.clock())
end

-- A plain-data snapshot for the client HUD. No instances, no functions,
-- so it survives the RemoteEvent trip untouched.
function State.snapshot(player, data)
	local owned = {}
	for _, entry in ipairs(data.owned) do
		table.insert(owned, {
			uid = entry.uid,
			id = entry.id,
			name = entry.name,
			rarity = entry.rarity,
			rate = entry.rate,
			multiplier = entry.multiplier,
			mutation = entry.mutation,
		})
	end
	return {
		cash = math.floor(data.cash),
		income = State.computeIncome(data),
		rebirths = data.rebirths,
		rebirthCost = Config.rebirthCost(data.rebirths),
		multiplier = Config.incomeMultiplier(data.rebirths),
		baseIndex = data.baseIndex,
		lockRemaining = State.lockRemaining(data),
		lockCooldown = State.lockCooldownRemaining(data),
		owned = owned,
	}
end

return State
