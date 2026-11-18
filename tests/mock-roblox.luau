-- Mock Roblox API: just enough of Instance / Color3 / Vector3 / CFrame /
-- UDim2 / Enum to run CharacterFactory (and Config) under the standalone
-- `luau` interpreter and inspect the model it builds.
--
-- This is a TEST double, not game code. It never ships in the .rbxl.
-- Run:  luau tests/verify-characters.luau   (from the repo root)

local Mock = {}

-- ---------- Vector3 ----------
local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	if typeof(x) == "table" and x.X ~= nil and y == nil then
		return setmetatable({ X = x.X, Y = x.Y, Z = x.Z }, Vector3)
	end
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function Vector3.__mul(a, b)
	if typeof(a) == "number" then
		return Vector3.new(a * b.X, a * b.Y, a * b.Z)
	end
	if typeof(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	end
	error("Vector3 * Vector3 is not a thing (mock)")
end
function Vector3.__unm(a)
	return Vector3.new(-a.X, -a.Y, -a.Z)
end
function Vector3.__tostring(v)
	return string.format("Vector3(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end
function Vector3.__eq(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
Mock.Vector3 = Vector3

-- ---------- CFrame ----------
-- Rotation stored as a row-major 3x3 matrix { m11,m12,m13, m21,m22,m23, m31,m32,m33 }.
-- Position is a Vector3. Only the operations the factory uses are implemented.
local function matMul(a, b)
	local o = {}
	for r = 0, 2 do
		for c = 0, 2 do
			o[r * 3 + c + 1] = a[r * 3 + 1] * b[c + 1] + a[r * 3 + 2] * b[3 + c + 1] + a[r * 3 + 3] * b[6 + c + 1]
		end
	end
	return o
end
local function matVec(m, v)
	return Vector3.new(
		m[1] * v.X + m[2] * v.Y + m[3] * v.Z,
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z
	)
end
local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function rotX(a)
	local c, s = math.cos(a), math.sin(a)
	return { 1, 0, 0, 0, c, -s, 0, s, c }
end
local function rotY(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end
local function rotZ(a)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(x, y, z)
	local pos
	if x == nil then
		pos = Vector3.new(0, 0, 0)
	elseif typeof(x) == "table" and x.X ~= nil then
		pos = Vector3.new(x.X, x.Y, x.Z)
	else
		pos = Vector3.new(x, y, z)
	end
	return setmetatable({ Position = pos, _rot = { table.unpack(IDENTITY) } }, CFrame)
end
function CFrame.Angles(rx, ry, rz)
	-- Roblox applies X, then Y, then Z; exact Euler order does not matter
	-- for this harness (only positions and "is it tilted" are asserted).
	local r = matMul(matMul(rotZ(rz or 0), rotY(ry or 0)), rotX(rx or 0))
	return setmetatable({ Position = Vector3.new(0, 0, 0), _rot = r }, CFrame)
end
function CFrame.fromAxisAngle(axis, angle)
	local len = math.sqrt(axis.X * axis.X + axis.Y * axis.Y + axis.Z * axis.Z)
	local x, y, z = axis.X / len, axis.Y / len, axis.Z / len
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local r = {
		t * x * x + c, t * x * y - s * z, t * x * z + s * y,
		t * x * y + s * z, t * y * y + c, t * y * z - s * x,
		t * x * z - s * y, t * y * z + s * x, t * z * z + c,
	}
	return setmetatable({ Position = Vector3.new(0, 0, 0), _rot = r }, CFrame)
end
function CFrame.__mul(a, b)
	return setmetatable({
		Position = a.Position + matVec(a._rot, b.Position),
		_rot = matMul(a._rot, b._rot),
	}, CFrame)
end
function CFrame.__tostring(cf)
	return string.format("CFrame(%s)", tostring(cf.Position))
end
Mock.CFrame = CFrame

-- ---------- Color3 ----------
local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255, _rgb = { r, g, b } }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b, _rgb = { math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5) } }
end
Mock.Color3 = Color3

-- ---------- UDim2 ----------
local UDim2 = {}
function UDim2.fromOffset(x, y)
	return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
end
function UDim2.fromScale(x, y)
	return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
end
function UDim2.new(xs, xo, ys, yo)
	return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
end
Mock.UDim2 = UDim2

-- ---------- Enum ----------
Mock.Enum = {
	PartType = { Ball = "Ball", Cylinder = "Cylinder", Block = "Block" },
	Material = {
		SmoothPlastic = "SmoothPlastic", Neon = "Neon", Glass = "Glass",
		Fabric = "Fabric", Wood = "Wood", Metal = "Metal", Grass = "Grass",
		Slate = "Slate", Concrete = "Concrete", Sand = "Sand",
	},
	Font = { FredokaOne = "FredokaOne", GothamBold = "GothamBold", Gotham = "Gotham" },
	TextXAlignment = { Center = "Center", Left = "Left", Right = "Right" },
	TextYAlignment = { Center = "Center", Top = "Top", Bottom = "Bottom" },
}

-- ---------- Instance ----------
local function mockSignal()
	return {
		Connect = function(_self, fn)
			return { Connected = true, Disconnect = function() end, _fn = fn }
		end,
	}
end

local function makeInstance(className)
	local inst = { ClassName = className, Name = className, _children = {} }
	if className == "ClickDetector" then
		inst.MouseClick = mockSignal()
	end
	local mt = {}
	mt.__index = function(t, k)
		if k == "GetChildren" then
			return function(self)
				local out = {}
				for _, c in ipairs(self._children) do table.insert(out, c) end
				return out
			end
		elseif k == "FindFirstChild" then
			return function(self, name)
				for _, c in ipairs(self._children) do
					if c.Name == name then return c end
				end
				return nil
			end
		elseif k == "GetDescendants" then
			return function(self)
				local out = {}
				local function walk(n)
					for _, c in ipairs(n._children) do
						table.insert(out, c)
						walk(c)
					end
				end
				walk(self)
				return out
			end
		elseif k == "PivotTo" then
			return function(self, cf)
				self._pivot = cf
			end
		elseif k == "GetPivot" then
			return function(self)
				return self._pivot or (self.PrimaryPart and self.PrimaryPart.CFrame) or CFrame.new()
			end
		elseif k == "Destroy" then
			return function(self)
				self.Parent = nil
			end
		end
		return rawget(t, k)
	end
	mt.__newindex = function(t, k, v)
		if k == "Parent" then
			local old = rawget(t, "Parent")
			if old then
				for i, c in ipairs(old._children) do
					if c == t then table.remove(old._children, i) break end
				end
			end
			rawset(t, "Parent", v)
			if v then table.insert(v._children, t) end
		else
			rawset(t, k, v)
		end
	end
	return setmetatable(inst, mt)
end

Mock.Instance = {
	new = function(className, parent)
		local inst = makeInstance(className)
		if parent then inst.Parent = parent end
		return inst
	end,
}

-- ---------- task ----------
Mock.task = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) fn(...) end,
	wait = function() return 0 end,
	delay = function(_t, fn, ...) fn(...) end,
}

-- ---------- workspace (a plain Instance the harness can parent to) ----------
Mock.Workspace = makeInstance("Workspace")
Mock.Workspace.Name = "Workspace"

return Mock
