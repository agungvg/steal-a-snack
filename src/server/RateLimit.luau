-- Steal a Snack: RateLimit.
-- Per-player sliding-window rate limits for every client-triggered
-- action. A RemoteEvent or ClickDetector with no rate limit is an
-- exploit: an autoclicker could fire buy/steal/lock/rebirth hundreds
-- of times a second. Every gate returns false when the player is over
-- their allowance, and the caller answers with a cooldown message
-- instead of running the action.

--!strict

local RateLimit = {}

-- key -> max calls inside windowSeconds. Buy/steal are the spammy ones
-- (a fast legit click is ~2/s); lock/rebirth are deliberate buttons.
local LIMITS = {
	buy = { max = 5, window = 2 },
	steal = { max = 5, window = 2 },
	lock = { max = 3, window = 10 },
	rebirth = { max = 3, window = 10 },
}

local attempts = {} :: { [Player]: { [string]: { number } } }

function RateLimit.check(player: Player, key: string): boolean
	local limit = LIMITS[key]
	if not limit then
		return true
	end
	local now = os.clock()
	local byPlayer = attempts[player]
	if not byPlayer then
		byPlayer = {}
		attempts[player] = byPlayer
	end
	local stamps = byPlayer[key]
	if not stamps then
		stamps = {}
		byPlayer[key] = stamps
	end
	-- Drop stamps older than the window, then count what is left.
	local kept = {}
	for _, stamp in ipairs(stamps) do
		if now - stamp < limit.window then
			table.insert(kept, stamp)
		end
	end
	byPlayer[key] = kept
	if #kept >= limit.max then
		return false
	end
	table.insert(kept, now)
	return true
end

function RateLimit.clear(player: Player)
	attempts[player] = nil
end

return RateLimit
