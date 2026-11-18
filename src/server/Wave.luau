-- Steal a Snack: Wave.
-- The Hunger Wave. Every 90 seconds a warning goes out on the HUD, and
-- ten seconds later the wave sweeps the map: every brainrot still
-- walking the conveyor is carried away, and every player caught outside
-- their own base is dragged home. Stay on your plot or lose the belt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Wave = {}

local running = false
Wave.active = false
Wave.nextWaveIn = Config.WAVE_PERIOD

function Wave.start(State, Bases, Spawner, alertAll)
	if running then
		return
	end
	running = true
	task.spawn(function()
		while true do
			for remaining = Config.WAVE_PERIOD, 1, -1 do
				Wave.nextWaveIn = remaining
				if remaining == Config.WAVE_WARN_SECONDS then
					alertAll("HUNGER WAVE IN " .. tostring(Config.WAVE_WARN_SECONDS) .. "s! GET BACK TO YOUR BASE!")
				end
				task.wait(1)
			end
			Wave.active = true
			Wave.nextWaveIn = 0
			alertAll("HUNGER WAVE! Run home!")
			Spawner.sweepWalkers()
			local sweepEnd = os.clock() + Config.WAVE_DURATION
			while os.clock() < sweepEnd do
				for player, data in pairs(State.players) do
					if player.Parent and not Bases.isInsideBase(player, data) then
						local center = Bases.baseCenter(data)
						local character = player.Character
						if character and center then
							local root = character:FindFirstChild("HumanoidRootPart")
							if root then
								root.CFrame = CFrame.new(center + Vector3.new(0, 3, 0))
							end
						end
					end
				end
				task.wait(0.5)
			end
			Wave.active = false
			Wave.nextWaveIn = Config.WAVE_PERIOD
			alertAll("Wave passed. The belt is hungry again soon.")
		end
	end)
end

return Wave
