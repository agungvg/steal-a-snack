-- Steal a Snack: State.
-- The one place all player state lives. Every other server module reads
-- and writes through here, so cash, brainrots, locks and rebirths can
-- never disagree between systems.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Leaderboard = require(script.Parent.Leaderboard)

local State = {}

export type OwnedEntry = {
	uid: string,
	id: string,
	name: string,
	rarity: string,
	rate: number,
	multiplier: number,
	mutation: string,
	color: Color3,
	size: number,
	slot: number,
}

export type PlayerData = {
	cash: number,
	rebirths: number,
	baseIndex: number,
	lockUntil: number,
	lockCooldownUntil: number,
	stealCooldownUntil: number,
	owned: { OwnedEntry },
}

State.players = {} :: { [Player]: PlayerData }
State.takenBases = {} :: { [number]: boolean }

function State.newPlayer(player: Player): PlayerData
	local data: PlayerData = {
		cash = Config.START_CASH,
		rebirths = 0,
		baseIndex = 0,
		lockUntil = 0,
		lockCooldownUntil = 0,
		stealCooldownUntil = 0,
		owned = {},
	}
	State.players[player] = data
	return data
end

function State.get(player: Player): PlayerData?
	return State.players[player]
end

function State.remove(player: Player)
	local data = State.players[player]
	if data and data.baseIndex > 0 then
		State.takenBases[data.baseIndex] = nil
	end
	State.players[player] = nil
end

function State.computeIncome(data: PlayerData): number
	local total = 0
	for _, entry in ipairs(data.owned) do
		total += entry.rate * entry.multiplier
	end
	return total * Config.incomeMultiplier(data.rebirths)
end

function State.addOwned(data: PlayerData, entry: OwnedEntry)
	table.insert(data.owned, entry)
end

function State.findOwned(data: PlayerData, uid: string): (OwnedEntry?, number?)
	for index, entry in ipairs(data.owned) do
		if entry.uid == uid then
			return entry, index
		end
	end
	return nil, nil
end

function State.removeOwned(data: PlayerData, uid: string): boolean
	local _, index = State.findOwned(data, uid)
	if index then
		table.remove(data.owned, index)
		return true
	end
	return false
end

function State.isLocked(data: PlayerData): boolean
	return os.clock() < data.lockUntil
end

function State.lockRemaining(data: PlayerData): number
	return math.max(0, data.lockUntil - os.clock())
end

function State.lockCooldownRemaining(data: PlayerData): number
	return math.max(0, data.lockCooldownUntil - os.clock())
end

function State.stealCooldownRemaining(data: PlayerData): number
	return math.max(0, data.stealCooldownUntil - os.clock())
end

export type OwnedSnapshot = {
	uid: string,
	id: string,
	name: string,
	rarity: string,
	rate: number,
	multiplier: number,
	mutation: string,
	color: Color3,
}

-- The snapshot the server sends the HUD. notice / nextWaveIn /
-- waveActive are filled in by init.server after the snapshot is built,
-- so they are optional here and required nowhere else.
export type Snapshot = {
	cash: number,
	income: number,
	rebirths: number,
	rebirthCost: number,
	multiplier: number,
	baseIndex: number,
	lockRemaining: number,
	lockCooldown: number,
	owned: { OwnedSnapshot },
	leaders: { { name: string, cash: number } },
	notice: string?,
	nextWaveIn: number?,
	waveActive: boolean?,
}

-- A plain-data snapshot for the client HUD. No instances, no functions,
-- so it survives the RemoteEvent trip untouched.
function State.snapshot(player: Player, data: PlayerData): Snapshot
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
			color = entry.color,
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
		leaders = Leaderboard.top(State.players, 5),
	}
end

return State
