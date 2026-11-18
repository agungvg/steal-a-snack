-- Steal a Snack: Bases.
-- Owns the eight plots around the conveyor: who holds which plot, the
-- six slots on each plot, the 3D brainrot models standing on them, and
-- the "am I home?" test the Hunger Wave uses. Each base also carries a
-- floating name label, so a screenshot shows at a glance whose base is
-- whose -- and whether it is locked.
--
-- Layout (top-creator reference: the original Steal a Brainrot): the
-- plots adjoin the belt -- their inner edge is a short walk from the
-- conveyor, so from your base the snacks walk past your front door.
-- A player is teleported onto their plot facing the belt the moment
-- they spawn, so the first frame is the game, not an empty field.

--!strict

local Workspace = game:GetService("Workspace")

local State = require(script.Parent.State)
local CharacterFactory = require(script.Parent.CharacterFactory)

local Bases = {}

Bases.Clicked = nil :: ((Player, string) -> ())?

-- Plot centres: two rows of four, inner edge a short walk from the
-- belt (belt edge Z=+/-5, plot inner edge Z=+/-8). Y=1 is the plot
-- platform's top surface.
Bases.CENTERS = {
	Vector3.new(-45, 1, -14),
	Vector3.new(-15, 1, -14),
	Vector3.new(15, 1, -14),
	Vector3.new(45, 1, -14),
	Vector3.new(-45, 1, 14),
	Vector3.new(-15, 1, 14),
	Vector3.new(15, 1, 14),
	Vector3.new(45, 1, 14),
}

-- Six slots per plot, 2 rows x 3 columns on a 22x12 platform.
local SLOT_OFFSETS = {
	Vector3.new(-7, 0, -3),
	Vector3.new(0, 0, -3),
	Vector3.new(7, 0, -3),
	Vector3.new(-7, 0, 3),
	Vector3.new(0, 0, 3),
	Vector3.new(7, 0, 3),
}

local modelsByUid = {} :: { [string]: Model }
local animated = {} :: { [string]: { model: Model, baseCFrame: CFrame, phase: number } }
local shields = {} :: { [number]: BasePart }
local labels = {} :: { [number]: { gui: BillboardGui, text: TextLabel } }
local labelOwner = {} :: { [number]: string? }
local labelLocked = {} :: { [number]: boolean }
local folder: Folder? = nil

local function getFolder(): Folder
	if not folder then
		local found = Workspace:FindFirstChild("Brainrots")
		if found and found:IsA("Folder") then
			folder = found
		else
			local created = Instance.new("Folder")
			created.Name = "Brainrots"
			created.Parent = Workspace
			folder = created
		end
	end
	return folder :: Folder
end

-- The floating name plate over a base: "BASE 3" on top, the owner's
-- name (or EMPTY) under it, and a LOCKED line while the lock is up.
-- One BillboardGui per base, created once and re-texted on change.
function Bases.refreshBaseLabel(baseIndex: number, ownerName: string?, locked: boolean?)
	if ownerName ~= nil then
		labelOwner[baseIndex] = ownerName
	end
	if locked ~= nil then
		labelLocked[baseIndex] = locked
	end
	local plate = Workspace:FindFirstChild("Base" .. tostring(baseIndex))
	if not plate or not plate:IsA("BasePart") then
		return
	end
	local entry = labels[baseIndex]
	if not entry then
		local gui = Instance.new("BillboardGui")
		gui.Name = "BaseLabel"
		gui.Size = UDim2.fromOffset(220, 72)
		gui.StudsOffset = Vector3.new(0, 8, 0)
		gui.AlwaysOnTop = false
		gui.Parent = plate
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 0.3
		text.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		text.TextStrokeTransparency = 0.3
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Parent = gui
		entry = { gui = gui, text = text }
		labels[baseIndex] = entry
	end
	local owner = labelOwner[baseIndex] or "EMPTY"
	local lockLine = labelLocked[baseIndex] and "\nLOCKED" or ""
	entry.text.Text = "BASE " .. tostring(baseIndex) .. "\n" .. owner .. lockLine
end

function Bases.clearBaseLabel(baseIndex: number)
	labelOwner[baseIndex] = nil
	labelLocked[baseIndex] = false
	local entry = labels[baseIndex]
	if entry then
		entry.text.Text = "BASE " .. tostring(baseIndex) .. "\nEMPTY"
	end
end

function Bases.assign(StateModule: any, data: State.PlayerData, ownerName: string): number
	for index = 1, #Bases.CENTERS do
		if not StateModule.takenBases[index] then
			StateModule.takenBases[index] = true
			data.baseIndex = index
			Bases.refreshBaseLabel(index, ownerName, false)
			return index
		end
	end
	data.baseIndex = 0
	return 0
end

function Bases.release(StateModule: any, data: State.PlayerData)
	if data.baseIndex > 0 then
		StateModule.takenBases[data.baseIndex] = nil
		Bases.clearBaseLabel(data.baseIndex)
		data.baseIndex = 0
	end
end

function Bases.getFreeSlot(data: State.PlayerData): number?
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

-- The ground point a slot's character stands on: the plot platform's
-- top surface. The factory builds the whole character upward from
-- this point, so a tall snack can never sink into its plot.
function Bases.slotPosition(baseIndex: number, slot: number): Vector3
	local center = Bases.CENTERS[baseIndex]
	if not center then
		return Vector3.new(0, 2, 0)
	end
	return center + SLOT_OFFSETS[slot]
end

function Bases.isInsideBase(player: Player, data: State.PlayerData): boolean
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local center = Bases.CENTERS[data.baseIndex]
	if not center then
		return false
	end
	local pos = root.Position
	return math.abs(pos.X - center.X) <= 11 and math.abs(pos.Z - center.Z) <= 6
end

function Bases.baseCenter(data: State.PlayerData): Vector3?
	return Bases.CENTERS[data.baseIndex]
end

-- Puts a player on their plot, facing the belt. Called the moment
-- their character loads, so nobody ever spawns staring at an empty
-- field: the first frame is their base with the conveyor in front.
function Bases.teleportToBase(player: Player, data: State.PlayerData)
	local center = Bases.CENTERS[data.baseIndex]
	if not center then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	-- A south plot (Z>0) faces north (-Z); a north plot faces south.
	-- A CFrame with no rotation already faces -Z.
	local target = CFrame.new(center + Vector3.new(0, 3, 0))
	if center.Z < 0 then
		target = target * CFrame.Angles(0, math.pi, 0)
	end
	root.CFrame = target
end

-- Builds the visible snack character through the shared factory: a
-- chunky character with a face, standing on its slot's ground point
-- and facing the belt. Clicking it tries a steal.
function Bases.buildModel(entry: State.OwnedEntry, position: Vector3): Model
	local model = CharacterFactory.build({
		id = entry.id,
		name = entry.name,
		color = entry.color,
		rarity = entry.rarity,
		mutation = entry.mutation,
		size = entry.size,
		position = position,
		labelText = entry.name
			.. "\n"
			.. entry.rarity
			.. (entry.mutation ~= "None" and (" " .. entry.mutation) or "")
			.. "  $" .. tostring(entry.rate * entry.multiplier) .. "/s",
		forward = Vector3.new(0, 0, 1),
		lateral = Vector3.new(1, 0, 0),
		billboardSize = UDim2.fromOffset(140, 56),
		clickDistance = 32,
		onClick = function(clickingPlayer: Player)
			if Bases.Clicked then
				Bases.Clicked(clickingPlayer, entry.uid)
			end
		end,
		parent = getFolder(),
	})

	modelsByUid[entry.uid] = model
	-- The bob pivots on the model's ground point, so the whole
	-- character breathes up and down without sinking or floating.
	animated[entry.uid] = { model = model, baseCFrame = model:GetPivot(), phase = math.random() * math.pi * 2 }
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
function Bases.setLockVisual(baseIndex: number, locked: boolean)
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

function Bases.placeOnBase(data: State.PlayerData, entry: State.OwnedEntry): number?
	local slot = Bases.getFreeSlot(data)
	if not slot then
		return nil
	end
	entry.slot = slot
	local position = Bases.slotPosition(data.baseIndex, slot)
	Bases.buildModel(entry, position)
	return slot
end

function Bases.removeModel(uid: string)
	local model = modelsByUid[uid]
	if model then
		model:Destroy()
		modelsByUid[uid] = nil
	end
	animated[uid] = nil
end

function Bases.clearBase(data: State.PlayerData)
	for _, entry in ipairs(data.owned) do
		Bases.removeModel(entry.uid)
	end
end

return Bases
