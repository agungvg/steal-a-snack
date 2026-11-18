-- Headless render-equivalent check for the snack characters.
--
-- There is no Roblox Studio on this VM, so this harness runs
-- CharacterFactory under the standalone `luau` interpreter against a
-- mock Roblox API (tests/mock-roblox.luau) and proves, for every snack
-- in Config.BRAINROTS, that the model it builds is a real, visible,
-- correctly-placed 3D character -- not a label floating over nothing.
--
-- What it asserts per snack (the exact failure mode Lyso hit):
--   * the model is a Model, parented to the workspace, with a PrimaryPart
--   * the PrimaryPart ("Root") is invisible and sits exactly on the
--     ground point (belt top), so PivotTo stands the model on the belt
--   * >= 5 VISIBLE parts (Transparency < 1), i.e. a multi-part body
--   * a face: 2 EyeWhite + 2 Pupil + 1 Mouth
--   * a "Disc" footprint lying flat on the ground (its centre 0.13 above
--     the belt top, 0.25 thick) -- the old bug was a vertical disc
--   * the name label is a real BillboardGui on the Root, NOT AlwaysOnTop,
--     floating s*1.15 above the ground, with the snack's name in it
--   * a ClickDetector on the main body (click-to-buy works)
--   * the bounding box of the visible parts: nothing buried below the
--     belt (minY >= ground - 0.05), real 3D volume (height >= 0.5*size
--     -- wide food characters like a taco, a lasagna stack or a cheese
--     wheel are legitimately squat, so the bar is "substantial", not
--     "tall"), wide enough to read (extent >= 0.8*size), and not
--     absurdly tall (maxY <= ground + 2.5*size)
--   * a mutated build wears a Neon MutationGem on top
--   * one snack is also built base-style (facing +Z, like Bases does)
--
-- The weather section (after the character loop) proves the sky system:
-- five definitions, pickNext never repeats, and per weather the exact
-- Lighting values, emitter rates, boosts and the snow ground tint —
-- the mock TweenService applies tweens at once, so set() lands the sky
-- immediately and the harness can assert the landed values. It never
-- calls Weather.start(): the cycle loop would spin forever on the
-- mock's instant task.wait.
--
-- NOTE: do not run this file directly with `luau`. The luau CLI's
-- require() isolates module globals, so the mock cannot be injected
-- through require. Run tests/run.sh instead: it assembles the mock,
-- Config, CharacterFactory and this file into ONE script (each module
-- wrapped in a function), so they all share one global environment.
-- When assembled, Mock / Config / CharacterFactory are already in scope.
-- The verdict is the RESULT: line at the end. PASS = every snack proven.

local GROUND = Vector3.new(0, Config.BELT_TOP_Y, 0) -- belt top, Y = 2
local fails = 0
local checks = 0

local function check(ok, msg)
	checks += 1
	if not ok then
		fails += 1
		print("    FAIL: " .. msg)
	end
end

local function approx(a, b, eps)
	return math.abs(a - b) <= (eps or 0.01)
end

-- Axis-aligned bounding box of a part, from its CFrame rotation + Size.
local function partAABB(part)
	local cf = part.CFrame
	local r = cf._rot
	local sx, sy, sz = part.Size.X / 2, part.Size.Y / 2, part.Size.Z / 2
	local ex = math.abs(r[1]) * sx + math.abs(r[2]) * sy + math.abs(r[3]) * sz
	local ey = math.abs(r[4]) * sx + math.abs(r[5]) * sy + math.abs(r[6]) * sz
	local ez = math.abs(r[7]) * sx + math.abs(r[8]) * sy + math.abs(r[9]) * sz
	local p = cf.Position
	return p.X - ex, p.Y - ey, p.Z - ez, p.X + ex, p.Y + ey, p.Z + ez
end

local function collectParts(model)
	local parts = {}
	local guis = {}
	local clickers = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d.ClassName == "Part" then
			table.insert(parts, d)
		elseif d.ClassName == "BillboardGui" then
			table.insert(guis, d)
		elseif d.ClassName == "ClickDetector" then
			table.insert(clickers, d)
		end
	end
	return parts, guis, clickers
end

local function verifySnack(b, mutation, forward, lateral, tag)
	local s = b.size
	local labelText = b.name .. "\n" .. b.rarity .. (mutation ~= "None" and (" " .. mutation) or "") .. "\n$" .. tostring(b.price) .. "/s"
	local model, mainBody = CharacterFactory.build({
		id = b.id,
		name = b.name,
		color = b.color,
		rarity = b.rarity,
		mutation = mutation,
		size = s,
		position = GROUND,
		labelText = labelText,
		forward = forward,
		lateral = lateral,
		billboardSize = UDim2.fromOffset(160, 64),
		clickDistance = 32,
		onClick = function(_player) end,
		parent = Mock.Workspace,
	})

	print(string.format("[%s] %s (%s, size %.1f) %s", b.id, b.name, b.rarity, s, tag))

	check(model.ClassName == "Model", "model is a Model, got " .. tostring(model.ClassName))
	check(model.Name == b.name, "model name is the snack name")
	check(model.Parent == Mock.Workspace, "model is parented to the workspace")

	local root = model.PrimaryPart
	check(root ~= nil, "PrimaryPart is set")
	if root then
		check(root.Name == "Root", "PrimaryPart is named Root")
		check(root.Transparency == 1, "Root is invisible (Transparency 1)")
		check(approx(root.Position.X, GROUND.X) and approx(root.Position.Y, GROUND.Y) and approx(root.Position.Z, GROUND.Z),
			"Root sits exactly on the ground point, got " .. tostring(root.Position))
	end

	local parts, guis, clickers = collectParts(model)

	-- Visible body parts.
	local visible = {}
	for _, p in ipairs(parts) do
		if p ~= root and (p.Transparency or 0) < 1 then
			table.insert(visible, p)
		end
	end
	check(#visible >= 5, string.format(">= 5 visible body parts, got %d", #visible))
	check(mainBody ~= nil and mainBody.ClassName == "Part", "build returns a main body part")
	if mainBody then
		check(mainBody.Parent == model, "main body is a child of the model")
	end

	-- Face.
	local eyes, pupils, mouths = 0, 0, 0
	local disc = nil
	local gem = nil
	for _, p in ipairs(visible) do
		if p.Name == "EyeWhite" then eyes += 1 end
		if p.Name == "Pupil" then pupils += 1 end
		if p.Name == "Mouth" then mouths += 1 end
		if p.Name == "Disc" then disc = p end
		if p.Name == "MutationGem" then gem = p end
	end
	check(eyes == 2, "2 eye whites, got " .. tostring(eyes))
	check(pupils == 2, "2 pupils, got " .. tostring(pupils))
	check(mouths == 1, "1 mouth, got " .. tostring(mouths))

	-- Ground disc: flat on the belt, not a vertical wheel.
	check(disc ~= nil, "a Disc footprint part exists")
	if disc then
		check(disc.Shape == Enum.PartType.Cylinder, "Disc is a Cylinder")
		check(approx(disc.CFrame.Position.Y, GROUND.Y + 0.13, 0.02),
			"Disc centre is 0.13 above the belt top, got Y=" .. string.format("%.3f", disc.CFrame.Position.Y))
		check(approx(disc.Size.X, 0.25, 0.01), "Disc is 0.25 thick (Size.X), got " .. tostring(disc.Size.X))
		check(approx(disc.Size.Y, s * 1.7, 0.05) and approx(disc.Size.Z, s * 1.7, 0.05),
			"Disc diameter is 1.7x size, got " .. tostring(disc.Size.Y) .. " x " .. tostring(disc.Size.Z))
		-- A vertical cylinder has its axis along Y: the rotation must move
		-- the X axis onto Y (R[2][1] ~= 1), i.e. it is stood up, not flat.
		local r = disc.CFrame._rot
		check(math.abs(r[5]) < 0.01 and math.abs(r[4]) > 0.99,
			"Disc is stood up (cylinder axis is vertical), not a vertical wheel")
	end

	-- Mutation gem.
	if mutation ~= "None" then
		check(gem ~= nil, "mutated snack wears a MutationGem")
		if gem then
			check(gem.Material == Enum.Material.Neon, "MutationGem glows (Neon)")
		end
	else
		check(gem == nil, "unmutated snack has no MutationGem")
	end

	-- Label: real world label, not AlwaysOnTop text.
	check(#guis == 1, "exactly 1 BillboardGui label, got " .. tostring(#guis))
	if #guis == 1 then
		local gui = guis[1]
		check(gui.Name == "Label", "label is named Label")
		check(gui.AlwaysOnTop == false, "label is NOT AlwaysOnTop (it behaves like the world)")
		check(approx(gui.StudsOffset.Y, s * 1.15, 0.01),
			"label floats 1.15x size above the ground, got " .. tostring(gui.StudsOffset.Y))
		local tl = gui:FindFirstChild("TextLabel")
		-- (FindFirstChild only searches direct children; the label is one.)
		if not tl then
			for _, c in ipairs(gui:GetChildren()) do
				if c.ClassName == "TextLabel" then tl = c end
			end
		end
		check(tl ~= nil, "label has a TextLabel child")
		if tl then
			check(tl.Text == labelText, "label text is the snack's name/rarity/price")
		end
	end

	-- Click-to-buy.
	check(#clickers == 1, "exactly 1 ClickDetector, got " .. tostring(#clickers))
	if #clickers == 1 then
		check(clickers[1].MaxActivationDistance == 32, "ClickDetector range is 32")
		check(clickers[1].Parent == mainBody, "ClickDetector sits on the main body")
	end

	-- Bounding box of the visible body: on the ground, big, not buried.
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, p in ipairs(visible) do
		local ax, ay, az, bx, by, bz = partAABB(p)
		minX, minY, minZ = math.min(minX, ax), math.min(minY, ay), math.min(minZ, az)
		maxX, maxY, maxZ = math.max(maxX, bx), math.max(maxY, by), math.max(maxZ, bz)
	end
	local height = maxY - minY
	local extent = math.max(maxX - minX, maxZ - minZ)
	check(minY >= GROUND.Y - 0.05,
		string.format("nothing buried: lowest visible point Y=%.2f (belt top %.2f)", minY, GROUND.Y))
	check(height >= s * 0.5,
		string.format("character has real 3D volume: height %.2f >= 0.5*size %.2f", height, s * 0.5))
	check(extent >= s * 0.8,
		string.format("character is wide enough: extent %.2f >= 0.8*size %.2f", extent, s * 0.8))
	check(maxY <= GROUND.Y + s * 2.5,
		string.format("character is not absurdly tall: top Y=%.2f <= %.2f", maxY, GROUND.Y + s * 2.5))
	print(string.format("    visible parts: %d | bbox Y %.2f..%.2f (height %.2f) | extent %.2f | top %.2f",
		#visible, minY, maxY, height, extent, maxY))
end

print("=== CharacterFactory headless verification ===")
print(string.format("belt top Y = %.1f, %d snacks in Config.BRAINROTS", GROUND.Y, #Config.BRAINROTS))

local beltFwd = Vector3.new(1, 0, 0)
local beltLat = Vector3.new(0, 0, 1)
for _, b in ipairs(Config.BRAINROTS) do
	verifySnack(b, "None", beltFwd, beltLat, "[belt]")
end

-- One mutated build + one base-style build (the two other call sites).
local ramen = Config.BRAINROTS[9]
verifySnack(ramen, "Golden", beltFwd, beltLat, "[belt, Golden mutation]")
local fry = Config.BRAINROTS[1]
verifySnack(fry, "None", Vector3.new(0, 0, 1), Vector3.new(1, 0, 0), "[base, faces belt]")

-- ---------- Weather system ----------
-- The mock TweenService applies tweens at once, so set() lands the sky
-- immediately and the harness asserts the landed values. Mock Color3
-- has no value equality (plain tables), so colours compare by _rgb.
print("=== Weather system headless verification ===")

local function sameColor(a, b)
	return a ~= nil and b ~= nil and a._rgb ~= nil and b._rgb ~= nil
		and a._rgb[1] == b._rgb[1] and a._rgb[2] == b._rgb[2] and a._rgb[3] == b._rgb[3]
end

-- Five definitions, distinct ids, every field present.
check(#Weather.DEFINITIONS == 5, "5 weather definitions, got " .. tostring(#Weather.DEFINITIONS))
local seenIds = {}
for _, def in ipairs(Weather.DEFINITIONS) do
	check(def.id ~= nil and def.name ~= nil and def.icon ~= nil and def.banner ~= nil and def.boost ~= nil,
		"weather " .. tostring(def.id) .. " has name/icon/banner/boost")
	check(seenIds[def.id] == nil, "weather id " .. tostring(def.id) .. " is unique")
	seenIds[def.id] = true
	check(Weather.BY_ID[def.id] == def, "BY_ID maps " .. tostring(def.id))
end
check(seenIds.Sunny and seenIds.Rain and seenIds.Storm and seenIds.Fog and seenIds.Snow,
	"all five weathers present: Sunny, Rain, Storm, Fog, Snow")

-- pickNext never repeats the current sky.
for _, id in ipairs({ "Sunny", "Rain", "Storm", "Fog", "Snow" }) do
	for _ = 1, 50 do
		check(Weather.pickNext(id) ~= id, "pickNext never repeats " .. id)
	end
end

local light = Mock.Lighting
local function findEmitter(name)
	local sky = Mock.Workspace:FindFirstChild("WeatherSky")
	if not sky then
		return nil
	end
	return sky:FindFirstChild(name)
end

-- Rain: dim grey sky, rain on, snow off, Rare+ weights lifted, banner.
local banner = ""
check(Weather.set("Rain", function(msg) banner = msg end, true), "set Rain succeeds")
check(light.Brightness == 1.8, "Rain brightness 1.8, got " .. tostring(light.Brightness))
check(light.FogEnd == 300, "Rain FogEnd 300, got " .. tostring(light.FogEnd))
local rainEmitter = findEmitter("RainEmitter")
local snowEmitter = findEmitter("SnowEmitter")
check(rainEmitter ~= nil and rainEmitter.Rate == 400, "Rain emitter rate 400")
check(snowEmitter ~= nil and snowEmitter.Rate == 0, "Snow emitter off in Rain")
check(string.sub(banner, 1, 8) == "WEATHER:", "Rain change announces with WEATHER: prefix")
check(string.find(banner, "RAIN") ~= nil, "Rain banner names RAIN")
local rainWeights = Weather.adjustedWeights()
check(rainWeights.Rare == 35 and rainWeights.Epic == 18.75 and rainWeights.Legendary == 10 and rainWeights.Mythic == 3.75,
	"Rain lifts Rare+ weights (35/18.75/10/3.75)")
local rarePlus = rainWeights.Rare + rainWeights.Epic + rainWeights.Legendary + rainWeights.Mythic
check(math.abs(rarePlus - 67.5) < 0.01,
	"Rain Rare+ share is 67.5% (54% x 1.25), got " .. tostring(rarePlus))
check(Weather.speedMultiplier() == 1, "Rain does not slow walkers")
check(Weather.incomeMultiplier() == 1, "Rain does not change income")

-- Storm: dimmest sky, heaviest rain, Legendary/Mythic weight doubled.
check(Weather.set("Storm", nil, true), "set Storm succeeds")
check(light.Brightness == 1.0, "Storm brightness 1.0 (dimmest), got " .. tostring(light.Brightness))
check(findEmitter("RainEmitter").Rate == 800, "Storm rain rate 800 (heaviest)")
local stormWeights = Weather.adjustedWeights()
check(stormWeights.Legendary == 16 and stormWeights.Mythic == 6,
	"Storm doubles Legendary/Mythic weights (16/6)")
local stormTotal = stormWeights.Common + stormWeights.Rare + stormWeights.Epic + stormWeights.Legendary + stormWeights.Mythic
local lmShare = (stormWeights.Legendary + stormWeights.Mythic) / stormTotal
check(math.abs(lmShare - 0.22) < 0.005,
	"Storm Legendary+Mythic share is 22% (11% x 2), got " .. string.format("%.3f", lmShare))

-- Fog: thick fog, walkers slowed to 75%.
check(Weather.set("Fog", nil, true), "set Fog succeeds")
check(light.FogEnd == 80, "Fog FogEnd 80 (thick), got " .. tostring(light.FogEnd))
check(Weather.speedMultiplier() == 0.75, "Fog slows walkers to 0.75x")
check(Weather.incomeMultiplier() == 1, "Fog does not change income")

-- Snow: cold sky, snow on, rain off, white ground, winter income bonus.
local plate = Instance.new("Part")
plate.Name = "Baseplate"
plate.Color = Color3.fromRGB(82, 184, 82)
plate.Material = Enum.Material.Grass
plate.Parent = Mock.Workspace
check(Weather.set("Snow", function(msg) banner = msg end, true), "set Snow succeeds")
check(light.Brightness == 2.1, "Snow brightness 2.1, got " .. tostring(light.Brightness))
check(findEmitter("SnowEmitter").Rate == 250, "Snow emitter rate 250")
check(findEmitter("RainEmitter").Rate == 0, "Rain emitter off in Snow")
check(sameColor(plate.Color, Color3.fromRGB(245, 247, 250)), "Snow turns the baseplate white")
check(plate.Material == Enum.Material.Snow, "Snow turns the baseplate to Snow material")
check(Weather.incomeMultiplier() == 1.25, "Snow pays +25% base income")
check(string.find(banner, "SNOW") ~= nil, "Snow banner names SNOW")

-- Leaving Snow restores the grass exactly.
check(Weather.set("Sunny", nil, true), "set Sunny succeeds")
check(sameColor(plate.Color, Color3.fromRGB(82, 184, 82)), "Sunny restores the baseplate colour")
check(plate.Material == Enum.Material.Grass, "Sunny restores the baseplate material")
check(light.Brightness == 2.5 and light.FogEnd == 420, "Sunny restores the bright clear sky")
check(findEmitter("RainEmitter").Rate == 0 and findEmitter("SnowEmitter").Rate == 0, "Sunny turns both emitters off")
check(Weather.speedMultiplier() == 1 and Weather.incomeMultiplier() == 1, "Sunny is the no-boost baseline")
local sunnyWeights = Weather.adjustedWeights()
check(sunnyWeights.Common == 46 and sunnyWeights.Rare == 28 and sunnyWeights.Mythic == 3,
	"Sunny spawns on the base weights")

-- Unknown weather is refused without touching the sky.
local before = Weather.current
check(Weather.set("Nope", nil, true) == false, "set rejects an unknown weather id")
check(Weather.current == before, "rejected set leaves the current weather alone")

print(string.format("=== %d checks, %d FAILURES ===", checks, fails))
if fails > 0 then
	print("RESULT: FAIL -- the characters or the weather are not proven. Fix the failing checks.")
else
	print("RESULT: PASS -- every snack builds as a real, visible, on-the-ground 3D character, and all five weathers land their sky, boost and ground.")
end
