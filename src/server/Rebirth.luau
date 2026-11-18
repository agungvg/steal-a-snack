-- Steal a Snack: Rebirth.
-- Cash in everything and climb again. A rebirth wipes your cash and
-- clears every brainrot off your base, and in return every future
-- dollar earns +25% more, forever, stacking with each rebirth.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Effects = require(script.Parent.Effects)

local Rebirth = {}

function Rebirth.tryRebirth(State, Bases, player)
	local data = State.get(player)
	if not data then
		return false, "No player state yet."
	end
	local cost = Config.rebirthCost(data.rebirths)
	if data.cash < cost then
		return false, "Rebirth costs $" .. tostring(cost) .. ". You have $" .. tostring(math.floor(data.cash)) .. "."
	end
	Bases.clearBase(data)
	table.clear(data.owned)
	data.cash = Config.START_CASH
	data.rebirths += 1
	local center = Bases.baseCenter(data)
	if center then
		Effects.rebirthBurst(center + Vector3.new(0, 4, 0))
	end
	return true, "REBIRTH #" .. tostring(data.rebirths) .. "! Income x" .. tostring(Config.incomeMultiplier(data.rebirths)) .. " forever."
end

return Rebirth
