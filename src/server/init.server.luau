-- Steal a Snack: server entry point.
-- Wires the services together: state, economy tick, conveyor, bases,
-- stealing, the Hunger Wave and rebirth, plus every RemoteEvent the
-- client HUD talks to. No game logic lives here, only wiring.
--
-- Remote contract (client -> server; the server decides everything):
--   LockBase (no args)        lock your base for 20s, 60s cooldown
--   RequestRebirth (no args)  trade everything for +25% income
-- Server -> client:
--   GameSync (snapshot)       cash, income, owned, leaders, timers
--   WaveAlert (string)        Hunger Wave warnings and rare spawns
-- Buying and stealing run through the ClickDetectors on the 3D models;
-- the server still validates each one (rate limit, range, state).

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.State)
local Bases = require(script.Bases)
local Economy = require(script.Economy)
local RateLimit = require(script.RateLimit)
local Rebirth = require(script.Rebirth)
local Saves = require(script.Saves)
local Spawner = require(script.Spawner)
local Steal = require(script.Steal)
local Wave = require(script.Wave)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameSync = Remotes:WaitForChild("GameSync")
local LockBase = Remotes:WaitForChild("LockBase")
local RequestRebirth = Remotes:WaitForChild("RequestRebirth")
local WaveAlert = Remotes:WaitForChild("WaveAlert")

local notices = {} :: { [Player]: string }

local function syncPlayer(player: Player, notice: string?)
	local data = State.get(player)
	if not data then
		return
	end
	local snapshot = State.snapshot(player, data)
	snapshot.notice = notice or notices[player] or ""
	snapshot.nextWaveIn = Wave.nextWaveIn
	snapshot.waveActive = Wave.active
	GameSync:FireClient(player, snapshot)
end

local function alertAll(message: string)
	WaveAlert:FireAllClients(message)
end

Players.PlayerAdded:Connect(function(player: Player)
	local data = State.newPlayer(player)
	Bases.assign(State, data, player.Name)
	local restored = Saves.loadInto(State, Bases, player, data)
	local greeting = "Welcome to Steal a Snack! Click a snack on the belt to buy it."
	if data.baseIndex == 0 then
		greeting = "Welcome to Steal a Snack! All 8 bases are taken right now."
	elseif restored then
		greeting = "Welcome back! Your snacks and cash were restored."
	end
	syncPlayer(player, greeting)
	-- Land the player on their plot facing the belt the moment their
	-- character loads (and again on every respawn), so the first frame
	-- is the game, not an empty field.
	local function land()
		Bases.teleportToBase(player, data)
	end
	if player.Character then
		land()
	end
	player.CharacterAdded:Connect(function(_character: Model)
		task.wait(0.2)
		land()
	end)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local data = State.get(player)
	if data then
		Saves.saveNow(player, data)
		Bases.clearBase(data)
		Bases.release(State, data)
		State.remove(player)
	end
	notices[player] = nil
	RateLimit.clear(player)
end)

game:BindToClose(function()
	Saves.saveAll(State)
end)

-- Clicking a brainrot on someone else's base tries to steal it.
-- Steal.onStolen already refreshes both players' HUDs.
Bases.Clicked = function(player: Player, uid: string)
	local _ok, message = Steal.trySteal(State, Bases, player, uid)
	notices[player] = message
	syncPlayer(player, message)
end

LockBase.OnServerEvent:Connect(function(player: Player)
	local _ok, message = Steal.tryLock(State, player)
	notices[player] = message
	syncPlayer(player, message)
end)

RequestRebirth.OnServerEvent:Connect(function(player: Player)
	if not RateLimit.check(player, "rebirth") then
		notices[player] = "Slow down! Too many clicks."
		syncPlayer(player, notices[player])
		return
	end
	local _ok, message = Rebirth.tryRebirth(State, Bases, player)
	notices[player] = message
	syncPlayer(player, message)
end)

Spawner.onBought = function(player: Player)
	syncPlayer(player)
end

Spawner.onRareSpawn = function(message: string)
	alertAll(message)
end

Steal.onStolen = function(thief: Player, victim: Player)
	syncPlayer(thief)
	syncPlayer(victim)
end

-- Seed the belt so the first player sees snacks walking already.
for _ = 1, 3 do
	Spawner.spawnOne()
end

Economy.start(State, syncPlayer)
Spawner.start()
Bases.start()
Wave.start(State, Bases, Spawner, alertAll)
Saves.start(State)

-- Keep every base's lock dome and name label in step with its lock
-- timer: the dome appears the moment a lock starts and fades the
-- moment it ends, and the label shows LOCKED while it is up.
task.spawn(function()
	while true do
		task.wait(1)
		for _, data in pairs(State.players) do
			if data.baseIndex > 0 then
				local locked = State.isLocked(data)
				Bases.setLockVisual(data.baseIndex, locked)
				Bases.refreshBaseLabel(data.baseIndex, nil, locked)
			end
		end
	end
end)

print("Steal a Snack server ready: " .. tostring(#Config.BRAINROTS) .. " brainrots, " .. tostring(#Bases.CENTERS) .. " bases.")
