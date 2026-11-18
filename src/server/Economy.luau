-- Steal a Snack: Economy.
-- The cash tick. Once a second, every player earns the combined rate of
-- the brainrots standing on their base, scaled by their rebirth
-- multiplier, and the new totals are pushed to their HUD.

--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Economy = {}

local running = false

function Economy.start(State: any, syncPlayer: (Player) -> ())
	if running then
		return
	end
	running = true
	task.spawn(function()
		while true do
			task.wait(Config.CASH_TICK_SECONDS)
			for player, data in pairs(State.players) do
				if player.Parent then
					data.cash += State.computeIncome(data)
					syncPlayer(player)
				end
			end
		end
	end)
end

return Economy
