-- Steal a Snack: Weather.
-- A rotating sky, Steal a Brainrot event style. Every ~150-180 seconds
-- the weather changes (never the same twice in a row): Sunny, Rain,
-- Storm, Fog, Snow. Lighting + Atmosphere tween smoothly between
-- weathers, rain and snow fall from particle emitters, lightning
-- flashes in storms, and the grass turns white while it snows. Every
-- weather also boosts something real, so the sky is gameplay, not
-- wallpaper: Rain lifts Rare+ spawn rates, Storm doubles the
-- Legendary/Mythic spawn weight, Fog slows the walkers, Snow pays +25%
-- base income. No custom asset IDs are used anywhere: the emitters run
-- on the engine's default soft particle, shaped by size/speed/colour.
--
-- Contract: Weather.start(alertAll) boots the cycle (Sunny first, no
-- banner) and announces every later change through alertAll, which the
-- server wires to the WaveAlert banner. Spawner reads adjustedWeights()
-- and speedMultiplier(); State reads incomeMultiplier(). Nothing here
-- touches bases, buying, stealing, rebirth, waves or saves.

--!strict

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type LightTarget = {
	brightness: number,
	clockTime: number,
	fogColor: Color3,
	fogEnd: number,
	ambient: Color3,
	outdoorAmbient: Color3,
	atmoDensity: number,
	atmoColor: Color3,
	atmoHaze: number,
	rainRate: number,
	snowRate: number,
}

export type WeatherDef = {
	id: string,
	name: string,
	icon: string,
	banner: string,
	boost: string,
	light: LightTarget,
}

local Weather = {
	current = "Sunny",
	currentName = "Sunny",
	currentIcon = "☀️",
	currentBoost = "No boost — clear skies.",
	nextChangeIn = Config.WEATHER_MIN_SECONDS,
}

-- The five skies. Sunny matches the place file's Lighting, so boot is
-- a no-op visually. Rain lifts Rare+ from 54% to 67.5% of spawns
-- (weights 32.5/35/18.75/10/3.75: Rare+ is exactly 54% x 1.25).
-- Storm doubles the Legendary+Mythic share from 11% to 22% (weights
-- 40.3/24.5/13.1/16/6: L+M is 22 of 99.9).
Weather.DEFINITIONS = {
	{
		id = "Sunny",
		name = "Sunny",
		icon = "☀️",
		banner = "SUNNY — Clear skies, happy snacking!",
		boost = "No boost — clear skies.",
		light = {
			brightness = 2.5,
			clockTime = 14,
			fogColor = Color3.fromRGB(178, 216, 255),
			fogEnd = 420,
			ambient = Color3.fromRGB(51, 51, 51),
			outdoorAmbient = Color3.fromRGB(102, 102, 115),
			atmoDensity = 0.25,
			atmoColor = Color3.fromRGB(191, 216, 255),
			atmoHaze = 1.5,
			rainRate = 0,
			snowRate = 0,
		},
	},
	{
		id = "Rain",
		name = "Rain",
		icon = "🌧",
		banner = "RAIN — Rare snacks spawn 25% more often!",
		boost = "Rare+ snacks spawn 25% more often!",
		light = {
			brightness = 1.8,
			clockTime = 14,
			fogColor = Color3.fromRGB(140, 158, 184),
			fogEnd = 300,
			ambient = Color3.fromRGB(36, 38, 46),
			outdoorAmbient = Color3.fromRGB(71, 77, 87),
			atmoDensity = 0.4,
			atmoColor = Color3.fromRGB(153, 173, 204),
			atmoHaze = 2,
			rainRate = 400,
			snowRate = 0,
		},
	},
	{
		id = "Storm",
		name = "Storm",
		icon = "⛈",
		banner = "STORM — Legendary & Mythic spawn weight DOUBLED! Lightning incoming!",
		boost = "Legendary + Mythic spawn weight DOUBLED!",
		light = {
			brightness = 1.0,
			clockTime = 15,
			fogColor = Color3.fromRGB(64, 71, 89),
			fogEnd = 200,
			ambient = Color3.fromRGB(18, 18, 26),
			outdoorAmbient = Color3.fromRGB(38, 41, 51),
			atmoDensity = 0.55,
			atmoColor = Color3.fromRGB(102, 115, 153),
			atmoHaze = 2.5,
			rainRate = 800,
			snowRate = 0,
		},
	},
	{
		id = "Fog",
		name = "Fog",
		icon = "🌫",
		banner = "FOG — Walkers move 25% slower. Easy pickings!",
		boost = "Walkers move 25% slower — easier to click!",
		light = {
			brightness = 1.6,
			clockTime = 14,
			fogColor = Color3.fromRGB(199, 204, 209),
			fogEnd = 80,
			ambient = Color3.fromRGB(46, 46, 51),
			outdoorAmbient = Color3.fromRGB(77, 77, 82),
			atmoDensity = 0.7,
			atmoColor = Color3.fromRGB(204, 209, 217),
			atmoHaze = 3,
			rainRate = 0,
			snowRate = 0,
		},
	},
	{
		id = "Snow",
		name = "Snow",
		icon = "❄️",
		banner = "SNOW — Base snacks earn +25% income! Winter bonus!",
		boost = "Base snacks earn +25% income — winter bonus!",
		light = {
			brightness = 2.1,
			clockTime = 14,
			fogColor = Color3.fromRGB(217, 230, 255),
			fogEnd = 260,
			ambient = Color3.fromRGB(89, 102, 128),
			outdoorAmbient = Color3.fromRGB(128, 140, 166),
			atmoDensity = 0.35,
			atmoColor = Color3.fromRGB(217, 230, 255),
			atmoHaze = 2,
			rainRate = 0,
			snowRate = 250,
		},
	},
} :: { WeatherDef }

Weather.BY_ID = {} :: { [string]: WeatherDef }
for _, def in ipairs(Weather.DEFINITIONS) do
	Weather.BY_ID[def.id] = def
end

local running = false
local rainEmitter: ParticleEmitter? = nil
local snowEmitter: ParticleEmitter? = nil
local snowSavedColor: Color3? = nil
local snowSavedMaterial: Enum.Material? = nil

-- One invisible, anchored plate high above the map; both weather
-- emitters live on it so rain and snow fall across the whole play
-- area. Created lazily on the first weather change, never per frame.
local function ensureEmitters()
	if rainEmitter then
		return
	end
	local sky = Instance.new("Part")
	sky.Name = "WeatherSky"
	sky.Anchored = true
	sky.CanCollide = false
	sky.CanQuery = false
	sky.Transparency = 1
	sky.Size = Vector3.new(300, 1, 300)
	sky.Position = Vector3.new(0, 50, 0)
	sky.Parent = Workspace

	-- Rain: small fast drops, near-vertical, a short life so they read
	-- as streaks, not floating dots.
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "RainEmitter"
	rain.Enabled = false
	rain.Rate = 0
	rain.Speed = NumberRange.new(60, 80)
	rain.Lifetime = NumberRange.new(0.7, 1)
	rain.Size = NumberSequence.new(0.15)
	rain.Transparency = NumberSequence.new(0.25)
	rain.Color = ColorSequence.new(Color3.fromRGB(170, 200, 230))
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.SpreadAngle = Vector2.new(5, 5)
	rain.Parent = sky
	rainEmitter = rain

	-- Snow: soft flakes that drift with the wind instead of falling
	-- straight down. Slow speed, long life, a wide spread, a sideways
	-- acceleration for the drift and a spin, so no two flakes fall the
	-- same way. The size fades out at the end of life.
	local snow = Instance.new("ParticleEmitter")
	snow.Name = "SnowEmitter"
	snow.Enabled = false
	snow.Rate = 0
	snow.Speed = NumberRange.new(6, 10)
	snow.Lifetime = NumberRange.new(5, 7)
	snow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.7, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.15),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	snow.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(45, 45)
	snow.Acceleration = Vector3.new(4, -0.5, 2)
	snow.RotSpeed = NumberRange.new(-90, 90)
	snow.Parent = sky
	snowEmitter = snow
end

-- While it snows the grass baseplate turns white and snowy; the
-- original colour and material are saved and restored the moment the
-- snow stops, so no other weather ever inherits a white map.
local function setSnowGround(on: boolean)
	local plate = Workspace:FindFirstChild("Baseplate")
	if not plate or not plate:IsA("BasePart") then
		return
	end
	if on then
		if not snowSavedColor then
			snowSavedColor = plate.Color
			snowSavedMaterial = plate.Material
		end
		plate.Color = Color3.fromRGB(245, 247, 250)
		plate.Material = Enum.Material.Snow
	elseif snowSavedColor then
		plate.Color = snowSavedColor
		plate.Material = snowSavedMaterial :: Enum.Material
		snowSavedColor = nil
		snowSavedMaterial = nil
	end
end

-- Tween the sky to a definition (or set it at once on boot). The
-- Atmosphere child is optional: a place built before it existed still
-- gets the Lighting half, never an error.
local function applyLighting(def: WeatherDef, instant: boolean)
	local target = def.light
	if instant then
		Lighting.Brightness = target.brightness
		Lighting.ClockTime = target.clockTime
		Lighting.FogColor = target.fogColor
		Lighting.FogEnd = target.fogEnd
		Lighting.Ambient = target.ambient
		Lighting.OutdoorAmbient = target.outdoorAmbient
		local atmo = Lighting:FindFirstChild("Atmosphere")
		if atmo and atmo:IsA("Atmosphere") then
			atmo.Density = target.atmoDensity
			atmo.Color = target.atmoColor
			atmo.Haze = target.atmoHaze
		end
		return
	end
	local info = TweenInfo.new(Config.WEATHER_TRANSITION_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(Lighting, info, {
		Brightness = target.brightness,
		ClockTime = target.clockTime,
		FogColor = target.fogColor,
		FogEnd = target.fogEnd,
		Ambient = target.ambient,
		OutdoorAmbient = target.outdoorAmbient,
	}):Play()
	local atmo = Lighting:FindFirstChild("Atmosphere")
	if atmo and atmo:IsA("Atmosphere") then
		TweenService:Create(atmo, info, {
			Density = target.atmoDensity,
			Color = target.atmoColor,
			Haze = target.atmoHaze,
		}):Play()
	end
end

-- Switch the sky now. Returns false for an unknown id (current weather
-- untouched). alertAll is the banner hook; pass nil on boot so the
-- server does not announce Sunny to an empty lobby.
function Weather.set(id: string, alertAll: ((string) -> ())?, instant: boolean?): boolean
	local def = Weather.BY_ID[id]
	if not def then
		return false
	end
	Weather.current = id
	Weather.currentName = def.name
	Weather.currentIcon = def.icon
	Weather.currentBoost = def.boost
	ensureEmitters()
	applyLighting(def, instant == true)
	if rainEmitter then
		rainEmitter.Rate = def.light.rainRate
		rainEmitter.Enabled = def.light.rainRate > 0
	end
	if snowEmitter then
		snowEmitter.Rate = def.light.snowRate
		snowEmitter.Enabled = def.light.snowRate > 0
	end
	setSnowGround(id == "Snow")
	if alertAll then
		alertAll("WEATHER: " .. def.banner)
	end
	return true
end

-- The next sky, never the one we are already under.
function Weather.pickNext(currentId: string): string
	local id = currentId
	while id == currentId do
		id = Weather.DEFINITIONS[math.random(1, #Weather.DEFINITIONS)].id
	end
	return id
end

-- Walkers crawl in fog, normal speed everywhere else.
function Weather.speedMultiplier(): number
	if Weather.current == "Fog" then
		return 0.75
	end
	return 1
end

-- Bases pay a winter bonus while it snows.
function Weather.incomeMultiplier(): number
	if Weather.current == "Snow" then
		return 1.25
	end
	return 1
end

-- Spawn weights for the current sky. Rain and Storm return adjusted
-- tables (see the DEFINITIONS comment for the exact shares); every
-- other sky spawns on the base table.
function Weather.adjustedWeights(): { [string]: number }
	if Weather.current == "Rain" then
		return { Common = 32.5, Rare = 35, Epic = 18.75, Legendary = 10, Mythic = 3.75 }
	elseif Weather.current == "Storm" then
		return { Common = 40.3, Rare = 24.5, Epic = 13.1, Legendary = 16, Mythic = 6 }
	end
	return Config.SPAWN_WEIGHTS
end

function Weather.start(alertAll: (string) -> ())
	if running then
		return
	end
	running = true
	-- Boot on Sunny, instantly: the place file already looks like
	-- this, and nobody is here to read a banner yet.
	Weather.set("Sunny", nil, true)
	task.spawn(function()
		while true do
			local cycle = math.random(Config.WEATHER_MIN_SECONDS, Config.WEATHER_MAX_SECONDS)
			for remaining = cycle, 1, -1 do
				Weather.nextChangeIn = remaining
				task.wait(1)
			end
			Weather.set(Weather.pickNext(Weather.current), alertAll, false)
		end
	end)
	-- Lightning: while a storm is overhead, the sky flashes every few
	-- seconds — a fast rise to near-white, then a slow fall back to
	-- the storm's own dim brightness.
	task.spawn(function()
		while true do
			task.wait(math.random(5, 10))
			if Weather.current == "Storm" then
				local storm = Weather.BY_ID.Storm
				TweenService:Create(
					Lighting,
					TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = 4.5 }
				):Play()
				task.wait(0.12)
				TweenService:Create(
					Lighting,
					TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Brightness = storm.light.brightness }
				):Play()
			end
		end
	end)
end

return Weather
