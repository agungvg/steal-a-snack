-- Steal a Snack: Steal.
-- The other half of the genre. Click a brainrot standing on someone
-- else's base to snatch it onto your own base -- unless their base lock
-- is up. Locking costs nothing but time: 20 seconds of safety, then a
-- 60 second cooldown before you can lock again.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Effects = require(script.Parent.Effects)
local RateLimit = require(script.Parent.RateLimit)

local Steal = {}

Steal.onStolen = nil :: ((Player, Player) -> ())?

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

-- Wired by init.server: Bases.Clicked points here. The server decides:
-- the uid must be a string, the thief must be rate-limited, alive and
-- close to the victim's slot, off their steal cooldown, and holding a
-- base with a free slot -- and the victim's lock must be down. Clicking
-- your own snack is a no-op with a clear message, not an error.
function Steal.trySteal(State: any, Bases: any, thief: Player, uid: any): (boolean, string)
	if typeof(uid) ~= "string" then
		return false, "Bad steal request."
	end
	if not RateLimit.check(thief, "steal") then
		return false, "Slow down! Too many clicks."
	end
	local thiefData = State.get(thief)
	if not thiefData then
		return false, "No player state yet."
	end
	if thiefData.baseIndex == 0 then
		return false, "No free base right now. Wait for a plot to open."
	end
	-- Your own snack: not a steal, and not an error either.
	if State.findOwned(thiefData, uid) then
		return false, "That snack is already yours!"
	end
	if State.stealCooldownRemaining(thiefData) > 0 then
		return false, "Steal is cooling down: " .. tostring(math.ceil(State.stealCooldownRemaining(thiefData))) .. "s left."
	end
	local where = playerPosition(thief)
	if not where then
		return false, "You need to be alive and in the world to steal."
	end
	for victim, victimData in pairs(State.players) do
		if victim ~= thief then
			local entry = State.findOwned(victimData, uid)
			if entry then
				if State.isLocked(victimData) then
					return false, victim.Name .. "'s base is LOCKED. Come back later!"
				end
				local slotPos = Bases.slotPosition(victimData.baseIndex, entry.slot)
				if (where - slotPos).Magnitude > Config.ACTION_RANGE then
					return false, "Too far from that snack. Get closer to " .. victim.Name .. "'s base!"
				end
				if not Bases.getFreeSlot(thiefData) then
					return false, "Your base is full. No room for stolen goods."
				end
				State.removeOwned(victimData, uid)
				Bases.removeModel(uid)
				entry.slot = 0
				Bases.placeOnBase(thiefData, entry)
				State.addOwned(thiefData, entry)
				thiefData.stealCooldownUntil = os.clock() + Config.STEAL_COOLDOWN
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
function Steal.tryLock(State: any, player: Player): (boolean, string)
	if not RateLimit.check(player, "lock") then
		return false, "Slow down! Too many lock clicks."
	end
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
