-- Steal a Snack: CharacterFactory.
-- The one place snack characters are built. The conveyor walker and the
-- base model were the same ball body, two eyes and floating label built
-- twice; now both call sites build through here, so a visual change
-- lands everywhere at once and the outline shows one named system.
-- Parts are anchored and un-welded on purpose: the spawner moves body
-- and eyes itself each tick, and the base bob moves the whole model
-- with PivotTo.

--!strict

local CharacterFactory = {}

export type CharacterOptions = {
	name: string,
	color: Color3,
	size: number,
	position: Vector3,
	labelText: string,
	-- Which way the eyes face: +X for belt walkers (they walk east),
	-- +Z for base models (they face the belt).
	forward: Vector3,
	lateral: Vector3,
	billboardSize: UDim2,
	clickDistance: number,
	onClick: ((Player) -> ())?,
	parent: Instance,
}

function CharacterFactory.build(opts: CharacterOptions): (Model, BasePart, { BasePart })
	local size = opts.size

	local model = Instance.new("Model")
	model.Name = opts.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(size, size, size)
	body.Color = opts.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = opts.position
	body.Parent = model

	-- Two eyes on the forward face, so the hop and the wobble read as
	-- a character, not a rolling ball.
	local eyes = {}
	local eyeOffset = size * 0.22
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(size * 0.22, size * 0.22, size * 0.22)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Position = opts.position
			+ opts.forward * (size * 0.48)
			+ Vector3.new(0, size * 0.18, 0)
			+ opts.lateral * (side * eyeOffset)
		eye.Parent = model
		table.insert(eyes, eye)
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = opts.billboardSize
	billboard.StudsOffset = Vector3.new(0, size * 0.9, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body

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
		clicker.Parent = body
		local handler = opts.onClick
		clicker.MouseClick:Connect(function(player: Player)
			handler(player)
		end)
	end

	model.PrimaryPart = body
	model.Parent = opts.parent
	return model, body, eyes
end

return CharacterFactory
