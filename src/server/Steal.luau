-- Steal a Snack: Steal.
-- The other half of the genre. Click a brainrot standing on someone
-- else's base to snatch it onto your own base -- unless their base lock
-- is up. Locking costs nothing but time: 20 seconds of safety, then a
-- 60 second cooldown before you can lock again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Effects = require(script.Parent.Effects)

local Steal = {}

-- Wired by init.server: Bases.Clicked points here.
function Steal.trySteal(State, Bases, thief, uid)
	local thiefData = State.get(thief)
	if not thiefData then
		return false, "No player state yet."
	end
	for victim, victimData in pairs(State.players) do
		if victim ~= thief then
			local entry = State.findOwned(victimData, uid)
			if entry then
				if State.isLocked(victimData) then
					return false, victim.Name .. "'s base is LOCKED. Come back later!"
				end
				if not Bases.getFreeSlot(thiefData) then
					return false, "Your base is full. No room for stolen goods."
				end
				State.removeOwned(victimData, uid)
				Bases.removeModel(uid)
				entry.slot = 0
				Bases.placeOnBase(thiefData, entry)
				State.addOwned(thiefData, entry)
				Effects.burst(Bases.slotPosition(thiefData.baseIndex, entry.slot), entry.color)
				if Steal.onStolen then
					Steal.onStolen(thief, victim)
				end
				return true, "Stole " .. entry.name .. " from " .. victim.Name .. "!"
			end
		end
	end
	return false, "That snack is not on anyone's base."
end

-- LockBase RemoteEvent handler. Returns true plus a message.
function Steal.tryLock(State, player)
	local data = State.get(player)
	if not data then
		return false, "No player state yet."
	end
	if State.isLocked(data) then
		return false, "Your base is already locked."
	end
	if State.lockCooldownRemaining(data) > 0 then
		return false, "Lock is cooling down: " .. tostring(math.ceil(State.lockCooldownRemaining(data))) .. "s left."
	end
	local now = os.clock()
	data.lockUntil = now + Config.LOCK_DURATION
	data.lockCooldownUntil = now + Config.LOCK_COOLDOWN
	return true, "Base locked for " .. tostring(Config.LOCK_DURATION) .. " seconds!"
end

return Steal
