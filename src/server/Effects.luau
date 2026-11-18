-- Steal a Snack: Effects.
-- One-shot visual feedback for the moments that matter. Buying, stealing
-- and rebirthing all pop the same way: a coloured particle burst at the
-- spot in the world, so the player always sees the moment something
-- good (or stolen) happens, even with the sound off.

--!strict

local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Effects = {}

-- A short burst of coloured sparks at a position. The anchor part is
-- invisible; only the particles show. Debris cleans it up on its own.
function Effects.burst(position: Vector3, color: Color3): Instance
	local anchor = Instance.new("Part")
	anchor.Name = "Burst"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Position = position
	anchor.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new(0.8)
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(24)

	Debris:AddItem(anchor, 2)
	return anchor
end

-- A bigger, golden burst for rebirths: the rarest moment in the game.
function Effects.rebirthBurst(position: Vector3)
	Effects.burst(position, Color3.fromRGB(255, 215, 0))
	Effects.burst(position + Vector3.new(0, 2, 0), Color3.fromRGB(180, 90, 255))
end

return Effects
