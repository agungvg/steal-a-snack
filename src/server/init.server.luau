-- Steal a Snack: server entry point.
-- Wires the services together: state, economy tick, conveyor, bases,
-- stealing, the Hunger Wave and rebirth, plus every RemoteEvent the
-- client HUD talks to. No game logic lives here, only wiring.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local State = require(script.Parent.State)
local Bases = require(script.Parent.Bases)
local Economy = require(script.Parent.Economy)
local Spawner = require(script.Parent.Spawner)
local Steal = require(script.Parent.Steal)
local Wave = require(script.Parent.Wave)
local Rebirth = require(script.Parent.Rebirth)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuyBrainrot = Remotes:WaitForChild("BuyBrainrot")
local GameSync = Remotes:WaitForChild("GameSync")
local LockBase = Remotes:WaitForChild("LockBase")
local RequestRebirth = Remotes:WaitForChild("RequestRebirth")
local StealBrainrot = Remotes:WaitForChild("StealBrainrot")
local WaveAlert = Remotes:WaitForChild("WaveAlert")

local notices = {}

local function syncPlayer(player, notice)
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

local function alertAll(message)
	WaveAlert:FireAllClients(message)
end

Players.PlayerAdded:Connect(function(player)
	local data = State.newPlayer(player)
	Bases.assign(State, data)
	syncPlayer(player, "Welcome to Steal a Snack! Click a snack on the belt to buy it.")
end)

Players.PlayerRemoving:Connect(function(player)
	local data = State.get(player)
	if data then
		Bases.clearBase(data)
		State.remove(player)
	end
	notices[player] = nil
end)

-- Clicking a brainrot on someone else's base tries to steal it.
Bases.Clicked = function(player, uid)
	local _ok, message = Steal.trySteal(State, Bases, player, uid)
	notices[player] = message
	syncPlayer(player, message)
	if _ok then
		for victim, victimData in pairs(State.players) do
			if victim ~= player and State.findOwned(victimData, uid) == nil then
				-- The victim lost one; refresh their HUD too.
				syncPlayer(victim)
			end
		end
	end
end

BuyBrainrot.OnServerEvent:Connect(function(player, uid)
	local _ok, message = Spawner.tryBuy(player, uid)
	notices[player] = message
	syncPlayer(player, message)
end)

StealBrainrot.OnServerEvent:Connect(function(player, uid)
	local _ok, message = Steal.trySteal(State, Bases, player, uid)
	notices[player] = message
	syncPlayer(player, message)
end)

LockBase.OnServerEvent:Connect(function(player)
	local _ok, message = Steal.tryLock(State, player)
	notices[player] = message
	syncPlayer(player, message)
end)

RequestRebirth.OnServerEvent:Connect(function(player)
	local _ok, message = Rebirth.tryRebirth(State, Bases, player)
	notices[player] = message
	syncPlayer(player, message)
end)

Spawner.onBought = function(player)
	syncPlayer(player)
end

Steal.onStolen = function(thief, victim)
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

-- Keep every base's lock dome in step with its lock timer: the dome
-- appears the moment a lock starts and fades the moment it ends.
task.spawn(function()
	while true do
		task.wait(1)
		for _, data in pairs(State.players) do
			if data.baseIndex > 0 then
				Bases.setLockVisual(data.baseIndex, State.isLocked(data))
			end
		end
	end
end)

print("Steal a Snack server ready: " .. tostring(#Config.BRAINROTS) .. " brainrots, " .. tostring(#Bases.CENTERS) .. " bases.")
