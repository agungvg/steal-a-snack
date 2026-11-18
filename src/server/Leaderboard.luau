-- Steal a Snack: Leaderboard.
-- The richest players on this server, for the HUD. Kept in memory from
-- server-truth cash, so the board can never be faked from the client.
-- A cross-server board would need an OrderedDataStore; inside one
-- server the in-memory board is exact, has no DataStore failure mode,
-- and is what the screenshots show.

--!strict

local Leaderboard = {}

function Leaderboard.top(players: { [Player]: any }, limit: number): { { name: string, cash: number } }
	local rows = {}
	for player, data in pairs(players) do
		if player.Parent and typeof(data.cash) == "number" then
			table.insert(rows, { name = player.Name, cash = math.floor(data.cash) })
		end
	end
	table.sort(rows, function(a, b)
		return a.cash > b.cash
	end)
	while #rows > limit do
		table.remove(rows)
	end
	return rows
end

return Leaderboard
