-- Steal a Snack: Wave.
-- The Hunger Wave. Every 90 seconds a warning goes out on the HUD, and
-- ten seconds later the wave sweeps the map: every brainrot still
-- walking the conveyor is carried away, and every player caught outside
-- their own base is dragged home. Stay on your plot or lose the belt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local Wave = {}

local running = false
Wave.active = false
Wave.nextWaveIn = Config.WAVE_PERIOD

-- The warning beacon by the spawn and the red wall that sweeps the map.
-- Both are plain parts from the place file; nil-safe if a build predates
-- them, so an old place file never errors the wave loop.
local function setBeacon(lit)
	local beacon = Workspace:FindFirstChild("WaveBeaconBall")
	if beacon then
		beacon.Color = lit and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(100, 15, 15)
		local light = beacon:FindFirstChild("WaveBeaconLight")
		if light then
			light.Brightness = lit and 4 or 1
		end
	end
end

local function setWall(transparency, x)
	local wall = Workspace:FindFirstChild("WaveWall")
	if wall then
		wall.Transparency = transparency
		if x then
			wall.Position = Vector3.new(x, 8, 0)
		end
	end
end

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
					setBeacon(true)
					alertAll("HUNGER WAVE IN " .. tostring(Config.WAVE_WARN_SECONDS) .. "s! GET BACK TO YOUR BASE!")
				end
				task.wait(1)
			end
			Wave.active = true
			Wave.nextWaveIn = 0
			alertAll("HUNGER WAVE! Run home!")
			Spawner.sweepWalkers()
			-- The red wall sweeps west to east across the whole map,
			-- carrying the belt away with it. Players caught outside
			-- their base are dragged home while it passes.
			local waveStart = os.clock()
			local sweepEnd = waveStart + Config.WAVE_DURATION
			while os.clock() < sweepEnd do
				local progress = (os.clock() - waveStart) / Config.WAVE_DURATION
				setWall(0.45, -90 + 180 * progress)
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
			setWall(1)
			setBeacon(false)
			Wave.active = false
			Wave.nextWaveIn = Config.WAVE_PERIOD
			alertAll("Wave passed. The belt is hungry again soon.")
		end
	end)
end

return Wave
