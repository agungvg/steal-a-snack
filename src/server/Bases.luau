-- Steal a Snack: Bases.
-- Owns the eight plots around the conveyor: who holds which plot, the
-- six slots on each plot, the 3D brainrot models standing on them, and
-- the "am I home?" test the Hunger Wave uses.

local Workspace = game:GetService("Workspace")

local Bases = {}

Bases.Clicked = nil

Bases.CENTERS = {
	Vector3.new(-45, 1, -32),
	Vector3.new(-15, 1, -32),
	Vector3.new(15, 1, -32),
	Vector3.new(45, 1, -32),
	Vector3.new(-45, 1, 32),
	Vector3.new(-15, 1, 32),
	Vector3.new(15, 1, 32),
	Vector3.new(45, 1, 32),
}

local SLOT_OFFSETS = {
	Vector3.new(-7, 0, -4),
	Vector3.new(0, 0, -4),
	Vector3.new(7, 0, -4),
	Vector3.new(-7, 0, 4),
	Vector3.new(0, 0, 4),
	Vector3.new(7, 0, 4),
}

local modelsByUid = {}
local animated = {}
local shields = {}
local folder = nil

local function getFolder()
	if not folder then
		folder = Workspace:FindFirstChild("Brainrots")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Brainrots"
			folder.Parent = Workspace
		end
	end
	return folder
end

function Bases.assign(State, data)
	for index = 1, #Bases.CENTERS do
		if not State.takenBases[index] then
			State.takenBases[index] = true
			data.baseIndex = index
			return index
		end
	end
	data.baseIndex = 0
	return 0
end

function Bases.release(State, data)
	if data.baseIndex > 0 then
		State.takenBases[data.baseIndex] = nil
		data.baseIndex = 0
	end
end

function Bases.getFreeSlot(data)
	local used = {}
	for _, entry in ipairs(data.owned) do
		used[entry.slot] = true
	end
	for slot = 1, 6 do
		if not used[slot] then
			return slot
		end
	end
	return nil
end

function Bases.slotPosition(baseIndex, slot)
	local center = Bases.CENTERS[baseIndex]
	if not center then
		return Vector3.new(0, 2, 0)
	end
	return center + SLOT_OFFSETS[slot] + Vector3.new(0, 1.5, 0)
end

function Bases.isInsideBase(player, data)
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local center = Bases.CENTERS[data.baseIndex]
	if not center then
		return false
	end
	local pos = root.Position
	return math.abs(pos.X - center.X) <= 11 and math.abs(pos.Z - center.Z) <= 8
end

function Bases.baseCenter(data)
	return Bases.CENTERS[data.baseIndex]
end

-- Builds the visible snack character: a coloured ball body, two eyes,
-- and a floating label with its name, rarity, rate and mutation.
function Bases.buildModel(entry, position)
	local model = Instance.new("Model")
	model.Name = entry.name

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(entry.size, entry.size, entry.size)
	body.Color = entry.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Position = position
	body.Parent = model

	local eyeOffset = entry.size * 0.22
	for _, side in ipairs({ -1, 1 }) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(entry.size * 0.22, entry.size * 0.22, entry.size * 0.22)
		eye.Color = Color3.fromRGB(20, 20, 20)
		eye.Material = Enum.Material.SmoothPlastic
		eye.Anchored = true
		eye.CanCollide = false
		eye.Position = position + Vector3.new(side * eyeOffset, entry.size * 0.18, entry.size * 0.48)
		eye.Parent = model
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(140, 56)
	billboard.StudsOffset = Vector3.new(0, entry.size * 0.9, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.35
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = entry.name
		.. "\n"
		.. entry.rarity
		.. (entry.mutation ~= "None" and (" " .. entry.mutation) or "")
		.. "  $" .. tostring(entry.rate * entry.multiplier) .. "/s"
	label.Parent = billboard

	local clicker = Instance.new("ClickDetector")
	clicker.MaxActivationDistance = 32
	clicker.Parent = body
	clicker.MouseClick:Connect(function(clickingPlayer)
		if Bases.Clicked then
			Bases.Clicked(clickingPlayer, entry.uid)
		end
	end)

	model.PrimaryPart = body
	model.Parent = getFolder()
	modelsByUid[entry.uid] = model
	animated[entry.uid] = { model = model, baseCFrame = body.CFrame, phase = math.random() * math.pi * 2 }
	return model
end

-- Gentle idle bob for every snack standing on a base. One loop moves
-- them all with a sine offset, so a full base visibly breathes.
function Bases.start()
	task.spawn(function()
		while true do
			task.wait(0.08)
			local now = os.clock()
			for _, anim in pairs(animated) do
				if anim.model.Parent then
					anim.model:PivotTo(anim.baseCFrame * CFrame.new(0, math.sin(now * 2 + anim.phase) * 0.15, 0))
				end
			end
		end
	end)
end

-- A translucent blue dome over a base while its lock is up, so a lock
-- is visible in the world, not only on the owner's HUD.
function Bases.setLockVisual(baseIndex, locked)
	local center = Bases.CENTERS[baseIndex]
	if not center then
		return
	end
	local shield = shields[baseIndex]
	if not shield then
		shield = Instance.new("Part")
		shield.Name = "LockShield" .. tostring(baseIndex)
		shield.Shape = Enum.PartType.Ball
		shield.Size = Vector3.new(26, 12, 20)
		shield.Color = Color3.fromRGB(80, 160, 255)
		shield.Material = Enum.Material.Neon
		shield.Anchored = true
		shield.CanCollide = false
		shield.Transparency = 1
		shield.Position = center + Vector3.new(0, 5, 0)
		shield.Parent = Workspace
		shields[baseIndex] = shield
	end
	shield.Transparency = locked and 0.85 or 1
end

function Bases.placeOnBase(data, entry)
	local slot = Bases.getFreeSlot(data)
	if not slot then
		return nil
	end
	entry.slot = slot
	local position = Bases.slotPosition(data.baseIndex, slot)
	Bases.buildModel(entry, position)
	return slot
end

function Bases.removeModel(uid)
	local model = modelsByUid[uid]
	if model then
		model:Destroy()
		modelsByUid[uid] = nil
	end
	animated[uid] = nil
end

function Bases.clearBase(data)
	for _, entry in ipairs(data.owned) do
		Bases.removeModel(entry.uid)
	end
end

return Bases
