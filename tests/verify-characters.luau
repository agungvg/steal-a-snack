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

print(string.format("=== %d checks, %d FAILURES ===", checks, fails))
if fails > 0 then
	print("RESULT: FAIL -- the characters are not proven to render. Fix the factory.")
else
	print("RESULT: PASS -- every snack builds as a real, visible, on-the-ground 3D character.")
end
