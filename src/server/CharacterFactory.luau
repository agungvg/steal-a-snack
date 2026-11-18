-- Steal a Snack: CharacterFactory.
-- Builds every snack character in the game -- the walkers on the belt
-- and the snacks standing on bases -- as a detailed, organic 3D
-- character with a face, limbs, a ground disc and a floating label.
--
-- Design (top-creator reference: the original Steal a Brainrot):
-- a Brainrot character is an object body PLUS humanoid limbs PLUS a
-- big expressive face PLUS a signature prop -- that is what makes it
-- read as a real 3D character instead of a coloured object. So every
-- snack here gets arms (tilted cylinders with hands), legs with shoes,
-- a face with eye-shine and blush, and layered, organic body shaping:
-- a burger is a bun dome + patty + lettuce + cheese + tomato + sesame,
-- a ramen bowl is bowl + broth + noodle swirl + egg + narutomaki +
-- chopsticks + steam. Rarity is on the disc (glowing colour for
-- Epic+); a mutation tints the character's main colour and adds a gem
-- on top. Part counts stay small (~24-29 per character, a few hundred
-- for the whole belt), so the place stays far under budget.
--
-- Contract: opts.position is the GROUND point the character stands on.
-- Every part is built above it. The model pivots on an invisible Root
-- part at that ground point (PrimaryPart), so the spawner and the bases
-- move the whole character with one Model:PivotTo -- no per-part
-- position sets, so a character can never fall apart into a label and
-- a missing body.

--!strict

local CharacterFactory = {}

export type CharacterOptions = {
	id: string,
	name: string,
	color: Color3,
	rarity: string,
	mutation: string,
	size: number,
	position: Vector3,
	labelText: string,
	-- Which way the face points: +X for belt walkers (they walk east),
	-- +Z for base models (they face the belt).
	forward: Vector3,
	lateral: Vector3,
	billboardSize: UDim2,
	clickDistance: number,
	onClick: ((Player) -> ())?,
	parent: Instance,
}

type Ctx = {
	model: Model,
	ground: Vector3,
	forward: Vector3,
	lateral: Vector3,
	s: number,
	color: Color3,
	rarity: string,
	mutation: string,
}

-- One entry: { disc colour, disc material, disc transparency }.
local RARITY_DISC = {
	Common = { Color3.fromRGB(25, 25, 30), Enum.Material.SmoothPlastic, 0.15 },
	Rare = { Color3.fromRGB(80, 170, 255), Enum.Material.SmoothPlastic, 0.2 },
	Epic = { Color3.fromRGB(180, 90, 255), Enum.Material.Neon, 0.3 },
	Legendary = { Color3.fromRGB(255, 170, 0), Enum.Material.Neon, 0.3 },
	Mythic = { Color3.fromRGB(255, 60, 120), Enum.Material.Neon, 0.3 },
}

local MUTATION_COLORS: { [string]: Color3 } = {
	Rainbow = Color3.fromRGB(255, 100, 220),
	Diamond = Color3.fromRGB(120, 220, 255),
	Golden = Color3.fromRGB(255, 215, 0),
}

-- A point in the character's local frame: f forward, u up, l lateral.
local function at(ctx: Ctx, f: number, u: number, l: number): Vector3
	return ctx.ground + ctx.forward * f + Vector3.new(0, u, 0) + ctx.lateral * l
end

local function addPart(
	ctx: Ctx,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	color: Color3,
	f: number,
	u: number,
	l: number,
	rot: CFrame?,
	material: Enum.Material?,
	transparency: number?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Transparency = transparency or 0
	part.Anchored = true
	part.CanCollide = false
	part.CFrame = CFrame.new(at(ctx, f, u, l)) * (rot or CFrame.new())
	part.Parent = ctx.model
	return part
end

-- A vertical cylinder (bowl, skewer, chopstick): the cylinder axis is
-- X by default, so rotate it flat once (axis up). A tilt around the
-- lateral axis leans it in the forward plane, if one is given.
local function addVerticalCylinder(
	ctx: Ctx,
	name: string,
	height: number,
	diameter: number,
	color: Color3,
	f: number,
	u: number,
	l: number,
	tiltDeg: number?,
	material: Enum.Material?
): BasePart
	local rot = CFrame.Angles(0, 0, math.rad(90))
	if tiltDeg then
		rot = CFrame.fromAxisAngle(ctx.lateral, math.rad(tiltDeg)) * rot
	end
	return addPart(ctx, name, Enum.PartType.Cylinder, Vector3.new(height, diameter, diameter), color, f, u, l, rot, material)
end

-- The readable face: two big white eyes with a coloured iris, black
-- pupils, a sparkle on each pupil, tapered brows, a small nose, pink
-- blush on the cheeks, and a smiling mouth, on the body's front
-- surface. faceF is how far forward the face plane sits from the
-- character's centre line; eyeU is the eye height. opts.mouth picks
-- the mouth style ("smile", "open" with a tongue, "smirk" tilted to
-- one side); opts.browTilt tilts the brows for expression. The face
-- is the character -- a blank face is the one thing a good low-poly
-- character must never have.
local function addFace(ctx: Ctx, faceF: number, eyeU: number, opts: { mouth: string?, browTilt: number? }?)
	local s = ctx.s
	local eyeGap = s * 0.17
	local eyeR = s * 0.11
	local pupilMat = if ctx.rarity == "Mythic" then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local mouthStyle = (opts and opts.mouth) or "smile"
	local browTilt = (opts and opts.browTilt) or 8
	for _, side in ipairs({ -1, 1 }) do
		addPart(ctx, "EyeWhite", Enum.PartType.Ball, Vector3.new(eyeR * 2, eyeR * 2, eyeR * 2),
			Color3.fromRGB(255, 255, 255), faceF, eyeU, side * eyeGap)
		-- Iris: a warm brown ring inside the white, so the eye reads
		-- as an eye and not a dot.
		addPart(ctx, "Iris", Enum.PartType.Ball, Vector3.new(eyeR * 1.4, eyeR * 1.4, eyeR * 1.4),
			Color3.fromRGB(90, 55, 25), faceF + s * 0.04, eyeU, side * eyeGap)
		addPart(ctx, "Pupil", Enum.PartType.Ball, Vector3.new(eyeR * 0.9, eyeR * 0.9, eyeR * 0.9),
			Color3.fromRGB(20, 20, 20), faceF + s * 0.07, eyeU, side * eyeGap, nil, pupilMat)
		-- Sparkle on the pupil: the eye catches the light.
		addPart(ctx, "EyeShine", Enum.PartType.Ball, Vector3.new(s * 0.04, s * 0.04, s * 0.04),
			Color3.fromRGB(255, 255, 255), faceF + s * 0.1, eyeU + s * 0.03, side * eyeGap - s * 0.02)
		-- Brow: a tapered bar above the eye. The two brows tilt by
		-- different amounts on purpose -- a perfect mirror reads as
		-- artificial, a small asymmetry reads as alive.
		local tilt = math.rad(if side < 0 then browTilt else browTilt + 4)
		addPart(ctx, "Brow", Enum.PartType.Block,
			Vector3.new(s * 0.03, s * 0.035, s * 0.17), Color3.fromRGB(60, 40, 25),
			faceF + s * 0.01, eyeU + s * 0.17, side * eyeGap,
			CFrame.fromAxisAngle(ctx.forward, tilt))
		-- Blush on the cheek, below and outside the eye.
		addPart(ctx, "Blush", Enum.PartType.Ball, Vector3.new(s * 0.09, s * 0.09, s * 0.09),
			Color3.fromRGB(255, 150, 170), faceF + s * 0.01, eyeU - s * 0.15, side * s * 0.3,
			nil, Enum.Material.SmoothPlastic, 0.25)
	end
	-- Nose: a small dash on the face centre line, so the face has
	-- relief in the side view instead of a flat plate.
	addPart(ctx, "Nose", Enum.PartType.Ball, Vector3.new(s * 0.07, s * 0.06, s * 0.07),
		Color3.fromRGB(150, 80, 50), faceF + s * 0.02, eyeU - s * 0.08, 0)
	-- A smile: wider than it is tall. A smirk tilts to one side; an
	-- open mouth shows a tongue.
	if mouthStyle == "smirk" then
		addPart(ctx, "Mouth", Enum.PartType.Ball, Vector3.new(s * 0.12, s * 0.08, s * 0.1),
			Color3.fromRGB(40, 20, 20), faceF + s * 0.02, eyeU - s * 0.17, s * 0.04,
			CFrame.fromAxisAngle(ctx.forward, math.rad(14)))
	elseif mouthStyle == "open" then
		addPart(ctx, "Mouth", Enum.PartType.Ball, Vector3.new(s * 0.14, s * 0.1, s * 0.1),
			Color3.fromRGB(40, 20, 20), faceF + s * 0.02, eyeU - s * 0.17, 0)
		addPart(ctx, "Tongue", Enum.PartType.Ball, Vector3.new(s * 0.08, s * 0.05, s * 0.08),
			Color3.fromRGB(255, 120, 140), faceF + s * 0.03, eyeU - s * 0.2, 0)
	else
		addPart(ctx, "Mouth", Enum.PartType.Ball, Vector3.new(s * 0.12, s * 0.08, s * 0.1),
			Color3.fromRGB(40, 20, 20), faceF + s * 0.02, eyeU - s * 0.17, 0)
	end
end

-- Arms: a cylinder leaning outward 25 degrees around the forward axis
-- plus a hand at its lower end, on each side. The lean sign depends on
-- the frame's handedness: h = +1 when (forward, up, lateral) is
-- right-handed (belt walkers), -1 when it is not (bases).
-- shoulderU is the shoulder height, shoulderL the body's half-width.
-- The hand is a palm plus a curled finger and a thumb -- a mitten
-- blob is the one thing a good low-poly character must never have.
-- pose "up" raises both arms (dancing, cheering); the default pose
-- hangs them at the sides.
local function addArms(ctx: Ctx, shoulderU: number, shoulderL: number, armColor: Color3, pose: string?)
	local s = ctx.s
	local h = ctx.forward.X * ctx.lateral.Z - ctx.forward.Z * ctx.lateral.X
	local armLen = s * 0.3
	local armDia = s * 0.09
	local tiltVal = if pose == "up" then 155 else 25
	local tilt = math.rad(tiltVal)
	for _, side in ipairs({ -1, 1 }) do
		local tiltDeg = -side * h * tiltVal
		local rot = CFrame.fromAxisAngle(ctx.forward, math.rad(tiltDeg)) * CFrame.Angles(0, 0, math.rad(90))
		addPart(ctx, "Arm", Enum.PartType.Cylinder, Vector3.new(armLen, armDia, armDia), armColor,
			0, shoulderU - s * 0.1, side * (shoulderL + s * 0.03), rot)
		-- Hand: at the arm's lower end -- outward and down from the centre.
		local handU = shoulderU - s * 0.1 - math.cos(tilt) * (armLen / 2 + s * 0.03)
		local handL = side * (shoulderL + s * 0.03 + math.sin(tilt) * (armLen / 2 + s * 0.03))
		addPart(ctx, "Hand", Enum.PartType.Ball, Vector3.new(s * 0.11, s * 0.11, s * 0.11), armColor,
			s * 0.02, handU, handL)
		-- Curled fingers: one short cylinder hanging below the palm,
		-- slightly forward, so the hand reads as a hand at any angle.
		addVerticalCylinder(ctx, "Finger", s * 0.06, s * 0.035, armColor,
			s * 0.05, handU - s * 0.04, handL)
		-- Thumb: a small ball on the palm's inner side.
		addPart(ctx, "Thumb", Enum.PartType.Ball, Vector3.new(s * 0.05, s * 0.05, s * 0.05), armColor,
			s * 0.02, handU + s * 0.01, handL - side * s * 0.05)
	end
end

-- Legs: a short cylinder plus a shoe (a flattened ball, longer
-- forward so it reads as a foot) on each side. The shoe's bottom sits
-- exactly on the ground.
local function addLegs(ctx: Ctx, legL: number, legColor: Color3, shoeColor: Color3)
	local s = ctx.s
	for _, side in ipairs({ -1, 1 }) do
		addVerticalCylinder(ctx, "Leg", s * 0.16, s * 0.1, legColor, 0, s * 0.08, side * legL)
		addPart(ctx, "Shoe", Enum.PartType.Ball, Vector3.new(s * 0.24, s * 0.1, s * 0.18), shoeColor,
			s * 0.05, s * 0.05, side * legL)
	end
end

-- One builder per snack. Each returns its main body part (the click
-- target). ctx.color is the snack's signature colour, already tinted by
-- its mutation when one is present; the builder uses it for the
-- character's main part and fixed accent colours for the rest.
local Builders: { [string]: (Ctx) -> BasePart } = {}

Builders.soggy_fry = function(ctx: Ctx): BasePart
	local s = ctx.s
	-- Red fry box (matte cardboard) with a white opening lip and a
	-- gold stripe, five fries poking out at different heights and
	-- tilts, ketchup on one, ketchup dripping down the front.
	local box = addPart(ctx, "FryBox", Enum.PartType.Block,
		Vector3.new(s * 0.5, s * 0.45, s * 0.4), Color3.fromRGB(220, 45, 45), 0, s * 0.28, 0,
		nil, Enum.Material.Fabric)
	addPart(ctx, "BoxLip", Enum.PartType.Block,
		Vector3.new(s * 0.52, s * 0.06, s * 0.42), Color3.fromRGB(255, 245, 235), 0, s * 0.5, 0)
	addPart(ctx, "BoxStripe", Enum.PartType.Block,
		Vector3.new(s * 0.52, s * 0.1, s * 0.42), ctx.color, 0, s * 0.32, 0)
	local fryHeights = { 0.5, 0.55, 0.6, 0.5, 0.45 }
	for i, lat in ipairs({ -0.2, -0.1, 0, 0.1, 0.2 }) do
		local tilt = (i - 3) * 10
		addPart(ctx, "Fry", Enum.PartType.Block,
			Vector3.new(s * 0.09, s * fryHeights[i], s * 0.09), Color3.fromRGB(255, 210, 90),
			0, s * 0.62, lat * s,
			CFrame.fromAxisAngle(ctx.lateral, math.rad(tilt)))
	end
	addPart(ctx, "Ketchup", Enum.PartType.Ball,
		Vector3.new(s * 0.09, s * 0.09, s * 0.09), Color3.fromRGB(220, 40, 40), 0, s * 0.88, -s * 0.2)
	for _, lat in ipairs({ -0.12, 0.14 }) do
		addPart(ctx, "KetchupDrip", Enum.PartType.Ball,
			Vector3.new(s * 0.07, s * 0.1, s * 0.07), Color3.fromRGB(200, 30, 30),
			s * 0.26, s * 0.38, lat * s)
	end
	addFace(ctx, s * 0.21, s * 0.3)
	addArms(ctx, s * 0.35, s * 0.22, Color3.fromRGB(220, 45, 45))
	addLegs(ctx, s * 0.12, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return box
end

Builders.noodle_ned = function(ctx: Ctx): BasePart
	local s = ctx.s
	local bowl = addVerticalCylinder(ctx, "Bowl", s * 0.35, s * 0.8, Color3.fromRGB(200, 60, 60), 0, s * 0.2, 0)
	addVerticalCylinder(ctx, "BowlRim", s * 0.06, s * 0.86, Color3.fromRGB(160, 40, 40), 0, s * 0.38, 0)
	-- Noodle swirl on top, a strand draped over the front edge, an egg.
	addPart(ctx, "Noodles", Enum.PartType.Ball,
		Vector3.new(s * 0.75, s * 0.3, s * 0.75), ctx.color, 0, s * 0.42, 0)
	addPart(ctx, "NoodleSwirl", Enum.PartType.Ball,
		Vector3.new(s * 0.3, s * 0.15, s * 0.3), Color3.fromRGB(255, 225, 150), s * 0.1, s * 0.5, s * 0.1)
	addPart(ctx, "NoodleStrand", Enum.PartType.Ball,
		Vector3.new(s * 0.12, s * 0.12, s * 0.12), ctx.color, s * 0.38, s * 0.32, s * 0.1)
	addPart(ctx, "Egg", Enum.PartType.Ball,
		Vector3.new(s * 0.2, s * 0.2, s * 0.2), Color3.fromRGB(255, 250, 240), s * 0.08, s * 0.52, -s * 0.15)
	addPart(ctx, "Yolk", Enum.PartType.Ball,
		Vector3.new(s * 0.1, s * 0.1, s * 0.1), Color3.fromRGB(255, 170, 30), s * 0.13, s * 0.56, -s * 0.15)
	-- Chilli flakes and spring onion on the noodles: the bowl is
	-- dressed, not plain.
	for _, pos in ipairs({ { -0.18, 0.5, -0.05 }, { 0.2, 0.5, 0.18 } }) do
		addPart(ctx, "ChiliFlake", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.06, s * 0.06), Color3.fromRGB(200, 40, 30),
			pos[1] * s, pos[2] * s, pos[3] * s)
	end
	for _, pos in ipairs({ { -0.05, 0.52, 0.22 }, { 0.12, 0.52, -0.22 } }) do
		addVerticalCylinder(ctx, "GreenOnion", s * 0.03, s * 0.06, Color3.fromRGB(80, 200, 90),
			pos[1] * s, pos[2] * s, pos[3] * s)
	end
	-- Two wisps of steam.
	addPart(ctx, "Steam", Enum.PartType.Ball,
		Vector3.new(s * 0.14, s * 0.14, s * 0.14), Color3.fromRGB(255, 255, 255), 0, s * 0.85, 0,
		nil, Enum.Material.SmoothPlastic, 0.5)
	addPart(ctx, "Steam2", Enum.PartType.Ball,
		Vector3.new(s * 0.11, s * 0.11, s * 0.11), Color3.fromRGB(255, 255, 255), -s * 0.12, s * 0.8, s * 0.08,
		nil, Enum.Material.SmoothPlastic, 0.55)
	for _, side in ipairs({ -1, 1 }) do
		addVerticalCylinder(ctx, "Chopstick", s * 0.75, s * 0.05, Color3.fromRGB(120, 80, 40),
			-s * 0.1, s * 0.65, side * s * 0.12, 18 * side)
	end
	addFace(ctx, s * 0.4, s * 0.22)
	addArms(ctx, s * 0.36, s * 0.36, Color3.fromRGB(200, 60, 60))
	addLegs(ctx, s * 0.16, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return bowl
end

Builders.dancing_dumpling = function(ctx: Ctx): BasePart
	local s = ctx.s
	local body = addPart(ctx, "Dumpling", Enum.PartType.Ball,
		Vector3.new(s * 0.8, s * 0.55, s * 0.8), ctx.color, 0, s * 0.32, 0,
		nil, Enum.Material.Fabric)
	-- Crimped pleats along the top seam.
	for _, lat in ipairs({ -0.18, 0, 0.18 }) do
		addPart(ctx, "Pleat", Enum.PartType.Ball,
			Vector3.new(s * 0.12, s * 0.12, s * 0.12), Color3.fromRGB(240, 220, 170), s * 0.05, s * 0.56, lat * s)
	end
	-- Pink bow on top and a tutu skirt: she dances. Two ruffle layers
	-- so the skirt has depth, and earrings that catch the light.
	for _, side in ipairs({ -1, 1 }) do
		addPart(ctx, "Bow", Enum.PartType.Block,
			Vector3.new(s * 0.18, s * 0.08, s * 0.12), Color3.fromRGB(255, 120, 170), 0, s * 0.62, side * s * 0.1)
		addPart(ctx, "Earring", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.06, s * 0.06), Color3.fromRGB(255, 120, 170),
			s * 0.36, s * 0.32, side * s * 0.42)
	end
	addPart(ctx, "BowKnot", Enum.PartType.Ball,
		Vector3.new(s * 0.1, s * 0.1, s * 0.1), Color3.fromRGB(255, 120, 170), 0, s * 0.62, 0)
	addVerticalCylinder(ctx, "Tutu", s * 0.05, s * 0.95, Color3.fromRGB(255, 150, 200), 0, s * 0.22, 0,
		nil, Enum.Material.SmoothPlastic).Transparency = 0.15
	addVerticalCylinder(ctx, "TutuRuffle", s * 0.04, s * 1.05, Color3.fromRGB(255, 180, 210), 0, s * 0.17, 0,
		nil, Enum.Material.SmoothPlastic).Transparency = 0.3
	-- Open laughing mouth, arms raised: she is mid-dance.
	addFace(ctx, s * 0.4, s * 0.35, { mouth = "open", browTilt = 12 })
	addArms(ctx, s * 0.35, s * 0.36, ctx.color, "up")
	addLegs(ctx, s * 0.15, ctx.color, Color3.fromRGB(255, 120, 170))
	return body
end

Builders.turbo_taco = function(ctx: Ctx): BasePart
	local s = ctx.s
	local shell = addPart(ctx, "Shell", Enum.PartType.Ball,
		Vector3.new(s * 0.8, s * 0.5, s * 0.8), ctx.color, 0, s * 0.3, 0,
		nil, Enum.Material.Fabric)
	-- The folded edge across the top of the shell.
	addPart(ctx, "ShellFold", Enum.PartType.Block,
		Vector3.new(s * 0.5, s * 0.08, s * 0.7), Color3.fromRGB(220, 140, 20), 0, s * 0.52, 0)
	-- Filling spilling out of the top: lettuce, tomato, cheese, jalapeno.
	addPart(ctx, "Lettuce", Enum.PartType.Ball,
		Vector3.new(s * 0.18, s * 0.18, s * 0.18), Color3.fromRGB(90, 200, 90), 0, s * 0.55, -s * 0.15)
	addPart(ctx, "Lettuce2", Enum.PartType.Ball,
		Vector3.new(s * 0.18, s * 0.18, s * 0.18), Color3.fromRGB(90, 200, 90), 0, s * 0.55, s * 0.2)
	addPart(ctx, "Tomato", Enum.PartType.Ball,
		Vector3.new(s * 0.16, s * 0.16, s * 0.16), Color3.fromRGB(220, 60, 60), 0, s * 0.58, s * 0.05)
	for _, lat in ipairs({ -0.05, 0.15 }) do
		addPart(ctx, "CheeseShred", Enum.PartType.Block,
			Vector3.new(s * 0.2, s * 0.04, s * 0.06), Color3.fromRGB(255, 210, 80), s * 0.05, s * 0.56, lat * s,
			CFrame.Angles(0, math.rad(20), 0))
	end
	addVerticalCylinder(ctx, "Jalapeno", s * 0.05, s * 0.14, Color3.fromRGB(60, 170, 60), 0, s * 0.6, -s * 0.05)
	-- Hot sauce dripping down the shell, a sour-cream dollop, a lime
	-- wedge on top: the taco is dressed, and he knows it (smirk).
	addPart(ctx, "HotSauce", Enum.PartType.Ball,
		Vector3.new(s * 0.08, s * 0.12, s * 0.08), Color3.fromRGB(200, 40, 20), s * 0.3, s * 0.28, -s * 0.2)
	addPart(ctx, "SourCream", Enum.PartType.Ball,
		Vector3.new(s * 0.14, s * 0.08, s * 0.14), Color3.fromRGB(255, 250, 245), s * 0.12, s * 0.58, s * 0.28)
	addPart(ctx, "Lime", Enum.PartType.Block,
		Vector3.new(s * 0.14, s * 0.05, s * 0.1), Color3.fromRGB(140, 220, 80), -s * 0.08, s * 0.6, s * 0.12,
		CFrame.Angles(0, math.rad(25), 0))
	addFace(ctx, s * 0.4, s * 0.32, { mouth = "smirk", browTilt = 6 })
	addArms(ctx, s * 0.36, s * 0.36, ctx.color)
	addLegs(ctx, s * 0.16, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return shell
end

Builders.lord_lasagna = function(ctx: Ctx): BasePart
	local s = ctx.s
	addPart(ctx, "Pasta", Enum.PartType.Block,
		Vector3.new(s * 0.7, s * 0.14, s * 0.55), Color3.fromRGB(255, 230, 180), 0, s * 0.12, 0)
	addPart(ctx, "Sauce", Enum.PartType.Block,
		Vector3.new(s * 0.72, s * 0.1, s * 0.57), Color3.fromRGB(200, 50, 40), 0, s * 0.24, 0)
	local cheese = addPart(ctx, "Cheese", Enum.PartType.Block,
		Vector3.new(s * 0.7, s * 0.14, s * 0.55), ctx.color, 0, s * 0.36, 0)
	addPart(ctx, "PastaTop", Enum.PartType.Block,
		Vector3.new(s * 0.68, s * 0.12, s * 0.53), Color3.fromRGB(255, 230, 180), 0, s * 0.47, 0,
		CFrame.Angles(0, math.rad(3), 0))
	-- Melted cheese dripping down the front.
	for _, lat in ipairs({ -0.15, 0.15 }) do
		addPart(ctx, "CheeseDrip", Enum.PartType.Ball,
			Vector3.new(s * 0.1, s * 0.1, s * 0.1), Color3.fromRGB(255, 200, 60), s * 0.3, s * 0.3, lat * s)
	end
	addPart(ctx, "Basil", Enum.PartType.Block,
		Vector3.new(s * 0.15, s * 0.05, s * 0.15), Color3.fromRGB(60, 160, 60), 0, s * 0.55, 0)
	-- An olive on top, one more cheese drip, and a pleated chef's hat
	-- (cloth, not plastic): the lord is dressed for service.
	addPart(ctx, "Olive", Enum.PartType.Ball,
		Vector3.new(s * 0.09, s * 0.09, s * 0.09), Color3.fromRGB(40, 40, 30), -s * 0.12, s * 0.56, -s * 0.12)
	addPart(ctx, "CheeseMelt", Enum.PartType.Ball,
		Vector3.new(s * 0.08, s * 0.12, s * 0.08), Color3.fromRGB(255, 200, 60), s * 0.3, s * 0.3, -s * 0.05)
	-- A lord wears a chef's hat.
	addVerticalCylinder(ctx, "HatBrim", s * 0.12, s * 0.3, Color3.fromRGB(255, 255, 255), 0, s * 0.6, 0,
		nil, Enum.Material.Fabric)
	addPart(ctx, "HatTop", Enum.PartType.Ball,
		Vector3.new(s * 0.28, s * 0.2, s * 0.28), Color3.fromRGB(255, 255, 255), 0, s * 0.7, 0,
		nil, Enum.Material.Fabric)
	for _, lat in ipairs({ -0.08, 0.08 }) do
		addPart(ctx, "HatPleat", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.1, s * 0.06), Color3.fromRGB(235, 235, 235), 0, s * 0.72, lat * s,
			nil, Enum.Material.Fabric)
	end
	addFace(ctx, s * 0.28, s * 0.32, { browTilt = 5 })
	addArms(ctx, s * 0.35, s * 0.34, Color3.fromRGB(255, 230, 180))
	addLegs(ctx, s * 0.16, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return cheese
end

Builders.queen_queso = function(ctx: Ctx): BasePart
	local s = ctx.s
	local wheel = addVerticalCylinder(ctx, "CheeseWheel", s * 0.35, s * 0.85, ctx.color, 0, s * 0.22, 0)
	addVerticalCylinder(ctx, "Rind", s * 0.08, s * 0.88, Color3.fromRGB(220, 170, 0), 0, s * 0.22, 0)
	for _, lat in ipairs({ -0.15, 0.15 }) do
		addPart(ctx, "CheeseHole", Enum.PartType.Ball,
			Vector3.new(s * 0.12, s * 0.12, s * 0.12), Color3.fromRGB(220, 170, 0), s * 0.38, s * 0.2, lat * s)
	end
	-- Gold crown: band, three spikes, a red gem.
	addVerticalCylinder(ctx, "CrownBand", s * 0.08, s * 0.5, Color3.fromRGB(255, 215, 0), 0, s * 0.42, 0,
		nil, Enum.Material.Metal)
	for _, lat in ipairs({ -0.12, 0, 0.12 }) do
		addVerticalCylinder(ctx, "CrownSpike", s * 0.16, s * 0.08, Color3.fromRGB(255, 215, 0),
			0, s * 0.48, lat * s, nil, Enum.Material.Metal)
	end
	addPart(ctx, "CrownGem", Enum.PartType.Ball,
		Vector3.new(s * 0.1, s * 0.1, s * 0.1), Color3.fromRGB(220, 40, 60), 0, s * 0.52, 0)
	-- A royal cape behind the wheel, a gold necklace band across the
	-- front, and ruby earrings: the queen is dressed, not just crowned.
	addPart(ctx, "Cape", Enum.PartType.Block,
		Vector3.new(s * 0.06, s * 0.4, s * 0.7), Color3.fromRGB(180, 30, 50), -s * 0.42, s * 0.3, 0,
		CFrame.fromAxisAngle(ctx.lateral, math.rad(-8)), Enum.Material.Fabric)
	-- A gold necklace draped across the wheel's front: three beads in
	-- a shallow arc, the middle one hanging lowest.
	for _, bead in ipairs({ { -0.22, 0.17 }, { 0, 0.11 }, { 0.22, 0.17 } }) do
		addPart(ctx, "NecklaceBead", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.06, s * 0.06), Color3.fromRGB(255, 215, 0),
			s * 0.43, s * bead[2], bead[1] * s, nil, Enum.Material.Metal)
	end
	for _, side in ipairs({ -1, 1 }) do
		addPart(ctx, "Earring", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.06, s * 0.06), Color3.fromRGB(220, 40, 60),
			s * 0.38, s * 0.25, side * s * 0.44)
	end
	-- A royal sceptre in her right hand (lateral + side).
	addVerticalCylinder(ctx, "Sceptre", s * 0.4, s * 0.04, Color3.fromRGB(255, 215, 0), s * 0.02, s * 0.22, s * 0.48,
		nil, Enum.Material.Metal)
	addPart(ctx, "SceptreGem", Enum.PartType.Ball,
		Vector3.new(s * 0.09, s * 0.09, s * 0.09), Color3.fromRGB(220, 40, 60), s * 0.02, s * 0.44, s * 0.48)
	addFace(ctx, s * 0.42, s * 0.25)
	addArms(ctx, s * 0.36, s * 0.38, ctx.color)
	addLegs(ctx, s * 0.16, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return wheel
end

Builders.king_kebab = function(ctx: Ctx): BasePart
	local s = ctx.s
	addVerticalCylinder(ctx, "Skewer", s * 0.95, s * 0.06, Color3.fromRGB(180, 180, 190), 0, s * 0.5, 0,
		nil, Enum.Material.Metal)
	local meat = addPart(ctx, "Meat", Enum.PartType.Ball,
		Vector3.new(s * 0.5, s * 0.5, s * 0.5), ctx.color, 0, s * 0.32, 0)
	addPart(ctx, "Pepper", Enum.PartType.Block,
		Vector3.new(s * 0.42, s * 0.18, s * 0.42), Color3.fromRGB(80, 180, 80), 0, s * 0.55, 0)
	addPart(ctx, "Tomato", Enum.PartType.Ball,
		Vector3.new(s * 0.42, s * 0.42, s * 0.42), Color3.fromRGB(220, 60, 60), 0, s * 0.75, 0)
	for _, u in ipairs({ 0.45, 0.65 }) do
		addVerticalCylinder(ctx, "OnionRing", s * 0.04, s * 0.5, Color3.fromRGB(255, 250, 240), 0, s * u, 0)
	end
	-- A little grill flame licking the stack from the side.
	addPart(ctx, "Flame", Enum.PartType.Ball,
		Vector3.new(s * 0.14, s * 0.14, s * 0.14), Color3.fromRGB(255, 120, 0), s * 0.2, s * 0.12, s * 0.15,
		nil, Enum.Material.Neon)
	-- Flatbread wrapped behind the stack, grill marks seared across
	-- the meat, and a wisp of smoke over the flame.
	addPart(ctx, "Flatbread", Enum.PartType.Block,
		Vector3.new(s * 0.08, s * 0.55, s * 0.5), Color3.fromRGB(230, 200, 150), -s * 0.28, s * 0.35, 0,
		CFrame.fromAxisAngle(ctx.lateral, math.rad(10)), Enum.Material.Fabric)
	for _, u in ipairs({ 0.28, 0.38 }) do
		addPart(ctx, "GrillMark", Enum.PartType.Block,
			Vector3.new(s * 0.02, s * 0.04, s * 0.4), Color3.fromRGB(90, 40, 20),
			s * 0.26, s * u, 0, CFrame.fromAxisAngle(ctx.forward, math.rad(20)))
	end
	addPart(ctx, "Smoke", Enum.PartType.Ball,
		Vector3.new(s * 0.12, s * 0.12, s * 0.12), Color3.fromRGB(200, 200, 200), s * 0.22, s * 0.3, s * 0.15,
		nil, Enum.Material.SmoothPlastic, 0.6)
	addFace(ctx, s * 0.25, s * 0.32, { browTilt = 5 })
	addArms(ctx, s * 0.35, s * 0.28, ctx.color)
	addLegs(ctx, s * 0.14, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return meat
end

Builders.baron_burger = function(ctx: Ctx): BasePart
	local s = ctx.s
	addVerticalCylinder(ctx, "BottomBun", s * 0.16, s * 0.78, Color3.fromRGB(220, 170, 110), 0, s * 0.12, 0,
		nil, Enum.Material.Fabric)
	local patty = addVerticalCylinder(ctx, "Patty", s * 0.16, s * 0.82, ctx.color, 0, s * 0.28, 0)
	addPart(ctx, "Cheese", Enum.PartType.Block,
		Vector3.new(s * 0.85, s * 0.06, s * 0.85), Color3.fromRGB(255, 200, 60), 0, s * 0.38, 0,
		CFrame.Angles(0, math.rad(45), 0))
	addPart(ctx, "CheeseDrip", Enum.PartType.Ball,
		Vector3.new(s * 0.1, s * 0.1, s * 0.1), Color3.fromRGB(255, 200, 60), s * 0.35, s * 0.34, s * 0.3)
	addPart(ctx, "Lettuce", Enum.PartType.Ball,
		Vector3.new(s * 0.2, s * 0.2, s * 0.2), Color3.fromRGB(90, 200, 90), s * 0.3, s * 0.42, -s * 0.2)
	addPart(ctx, "Lettuce2", Enum.PartType.Ball,
		Vector3.new(s * 0.2, s * 0.2, s * 0.2), Color3.fromRGB(90, 200, 90), s * 0.3, s * 0.42, s * 0.2)
	addVerticalCylinder(ctx, "TomatoSlice", s * 0.06, s * 0.7, Color3.fromRGB(220, 60, 60), 0, s * 0.44, 0)
	addPart(ctx, "TopBun", Enum.PartType.Ball,
		Vector3.new(s * 0.78, s * 0.35, s * 0.78), Color3.fromRGB(230, 180, 120), 0, s * 0.55, 0,
		nil, Enum.Material.Fabric)
	for _, lat in ipairs({ -0.12, 0, 0.12 }) do
		addPart(ctx, "Sesame", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.06, s * 0.06), Color3.fromRGB(255, 245, 220), s * 0.15, s * 0.72, lat * s)
	end
	-- A pickle slice and an onion ring on the patty, a mustard drip
	-- down the front, two more sesame seeds: the baron is stacked.
	addVerticalCylinder(ctx, "Pickle", s * 0.04, s * 0.2, Color3.fromRGB(90, 170, 70), s * 0.2, s * 0.5, -s * 0.18)
	addVerticalCylinder(ctx, "OnionRing", s * 0.03, s * 0.3, Color3.fromRGB(255, 250, 240), s * 0.1, s * 0.36, -s * 0.2)
	addPart(ctx, "MustardDrip", Enum.PartType.Ball,
		Vector3.new(s * 0.08, s * 0.11, s * 0.08), Color3.fromRGB(255, 215, 40), s * 0.36, s * 0.32, -s * 0.32)
	for _, lat in ipairs({ -0.2, 0.2 }) do
		addPart(ctx, "Sesame", Enum.PartType.Ball,
			Vector3.new(s * 0.06, s * 0.06, s * 0.06), Color3.fromRGB(255, 245, 220), -s * 0.05, s * 0.7, lat * s)
	end
	addFace(ctx, s * 0.41, s * 0.28, { browTilt = 5 })
	addArms(ctx, s * 0.35, s * 0.38, Color3.fromRGB(230, 180, 120))
	addLegs(ctx, s * 0.16, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return patty
end

Builders.eternal_ramen = function(ctx: Ctx): BasePart
	local s = ctx.s
	local bowl = addVerticalCylinder(ctx, "Bowl", s * 0.32, s * 0.9, ctx.color, 0, s * 0.2, 0)
	addVerticalCylinder(ctx, "BowlRim", s * 0.06, s * 0.94, Color3.fromRGB(255, 250, 240), 0, s * 0.36, 0)
	addPart(ctx, "Broth", Enum.PartType.Ball,
		Vector3.new(s * 0.85, s * 0.22, s * 0.85), Color3.fromRGB(255, 160, 60), 0, s * 0.4, 0)
	-- Noodle swirl, a soft egg, and a narutomaki slice on the broth.
	addPart(ctx, "Noodles", Enum.PartType.Ball,
		Vector3.new(s * 0.5, s * 0.2, s * 0.5), Color3.fromRGB(255, 220, 140), 0, s * 0.48, 0)
	addPart(ctx, "NoodleSwirl", Enum.PartType.Ball,
		Vector3.new(s * 0.25, s * 0.12, s * 0.25), Color3.fromRGB(255, 230, 160), s * 0.15, s * 0.52, s * 0.1)
	addPart(ctx, "Egg", Enum.PartType.Ball,
		Vector3.new(s * 0.22, s * 0.22, s * 0.22), Color3.fromRGB(255, 250, 240), s * 0.1, s * 0.5, -s * 0.15)
	addPart(ctx, "Yolk", Enum.PartType.Ball,
		Vector3.new(s * 0.12, s * 0.12, s * 0.12), Color3.fromRGB(255, 170, 30), s * 0.16, s * 0.54, -s * 0.15)
	addVerticalCylinder(ctx, "Narutomaki", s * 0.08, s * 0.16, Color3.fromRGB(255, 250, 240), -s * 0.15, s * 0.5, s * 0.15)
	addPart(ctx, "NarutoSwirl", Enum.PartType.Ball,
		Vector3.new(s * 0.07, s * 0.07, s * 0.07), Color3.fromRGB(255, 120, 170), -s * 0.15, s * 0.54, s * 0.15)
	-- Steam over the bowl.
	addPart(ctx, "Steam", Enum.PartType.Ball,
		Vector3.new(s * 0.16, s * 0.16, s * 0.16), Color3.fromRGB(255, 255, 255), 0, s * 0.85, 0,
		nil, Enum.Material.SmoothPlastic, 0.5)
	addPart(ctx, "Steam2", Enum.PartType.Ball,
		Vector3.new(s * 0.12, s * 0.12, s * 0.12), Color3.fromRGB(255, 255, 255), s * 0.14, s * 0.82, -s * 0.1,
		nil, Enum.Material.SmoothPlastic, 0.55)
	-- Nori standing in the broth, a chashu slice, bamboo shoots, and
	-- a swirl of chilli oil: the eternal bowl is fully dressed.
	addPart(ctx, "Nori", Enum.PartType.Block,
		Vector3.new(s * 0.04, s * 0.3, s * 0.25), Color3.fromRGB(30, 60, 30), -s * 0.2, s * 0.55, -s * 0.2,
		CFrame.Angles(0, math.rad(15), 0))
	addVerticalCylinder(ctx, "Chashu", s * 0.06, s * 0.24, Color3.fromRGB(255, 200, 190), s * 0.18, s * 0.5, s * 0.22)
	addPart(ctx, "BambooShoot", Enum.PartType.Block,
		Vector3.new(s * 0.16, s * 0.05, s * 0.06), Color3.fromRGB(230, 200, 110), -s * 0.05, s * 0.52, s * 0.28,
		CFrame.Angles(0, math.rad(-20), 0))
	addPart(ctx, "ChiliOil", Enum.PartType.Ball,
		Vector3.new(s * 0.12, s * 0.06, s * 0.12), Color3.fromRGB(200, 50, 20), -s * 0.22, s * 0.5, s * 0.05)
	for _, side in ipairs({ -1, 1 }) do
		addVerticalCylinder(ctx, "Chopstick", s * 0.75, s * 0.05, Color3.fromRGB(90, 60, 40),
			-s * 0.15, s * 0.65, side * s * 0.1, 15 * side)
	end
	addFace(ctx, s * 0.45, s * 0.22)
	addArms(ctx, s * 0.36, s * 0.4, ctx.color)
	addLegs(ctx, s * 0.18, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return bowl
end

-- Fallback for any snack without its own builder: a ball body with the
-- same face and disc, so a new cast member can never be invisible.
local function buildGeneric(ctx: Ctx): BasePart
	local s = ctx.s
	local body = addPart(ctx, "Body", Enum.PartType.Ball,
		Vector3.new(s, s, s), ctx.color, 0, s * 0.5, 0)
	addFace(ctx, s * 0.48, s * 0.55)
	addArms(ctx, s * 0.5, s * 0.45, ctx.color)
	addLegs(ctx, s * 0.2, Color3.fromRGB(60, 40, 40), Color3.fromRGB(80, 50, 30))
	return body
end

function CharacterFactory.build(opts: CharacterOptions): (Model, BasePart)
	local s = opts.size

	local model = Instance.new("Model")
	model.Name = opts.name

	-- Invisible pivot at the ground point. The model pivots on this, so
	-- one PivotTo stands the whole character on the belt or its base.
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Shape = Enum.PartType.Block
	root.Size = Vector3.new(0.5, 0.5, 0.5)
	root.Color = Color3.fromRGB(255, 255, 255)
	root.Material = Enum.Material.SmoothPlastic
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.Position = opts.position
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Ctx = {
		model = model,
		ground = opts.position,
		forward = opts.forward,
		lateral = opts.lateral,
		s = s,
		color = opts.color,
		rarity = opts.rarity,
		mutation = opts.mutation,
	}

	-- Ground disc: the character's footprint. Its colour is its rarity
	-- (glowing for Epic+), so a rare snack pops from across the map.
	local discSpec = RARITY_DISC[opts.rarity] or RARITY_DISC.Common
	local discColor, discMaterial, discTransparency = discSpec[1], discSpec[2], discSpec[3]
	addVerticalCylinder(ctx, "Disc", 0.25, s * 1.7, discColor, 0, 0.13, 0, nil, discMaterial).Transparency = discTransparency

	local builder = Builders[opts.id] or buildGeneric
	local mainBody = builder(ctx)

	-- A mutated snack wears its mutation as a gem on top.
	if opts.mutation ~= "None" then
		local gemColor = MUTATION_COLORS[opts.mutation] or Color3.fromRGB(255, 255, 255)
		addPart(ctx, "MutationGem", Enum.PartType.Ball,
			Vector3.new(s * 0.18, s * 0.18, s * 0.18), gemColor, 0, s * 0.95, 0, nil, Enum.Material.Neon)
	end

	-- Name label, high above the character's tallest feature. It is a
	-- real 3D label (not AlwaysOnTop): it behaves like the world, so
	-- the character -- not the text -- is what you notice first.
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = opts.billboardSize
	billboard.StudsOffset = Vector3.new(0, s * 1.15, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = opts.labelText
	label.Parent = billboard

	if opts.onClick then
		local clicker = Instance.new("ClickDetector")
		clicker.MaxActivationDistance = opts.clickDistance
		clicker.Parent = mainBody
		local handler = opts.onClick
		clicker.MouseClick:Connect(function(player: Player)
			handler(player)
		end)
	end

	model.Parent = opts.parent
	return model, mainBody
end

return CharacterFactory
