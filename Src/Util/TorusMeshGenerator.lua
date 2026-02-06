--!strict
--[[
	TorusMeshGenerator.lua - Generates torus wireframe geometry
	
	Creates a wireframe visualization of a torus using thin cylinder parts.
	This accurately represents the mathematical torus shape used in brush operations.
	
	Torus parametric equations:
	x = (R + r*cos(v)) * cos(u)
	y = r * sin(v)
	z = (R + r*cos(v)) * sin(u)
	
	Where:
	- R = major radius (distance from center to tube center)
	- r = minor radius (tube thickness)
	- u = angle around the ring (0 to 2π)
	- v = angle around the tube cross-section (0 to 2π)
]]

local TorusMeshGenerator = {}

-- Configuration
local RING_SEGMENTS = 24 -- Segments around the main ring (u direction)
local TUBE_SEGMENTS = 12 -- Segments around the tube cross-section (v direction)
local WIRE_THICKNESS = 0.08 -- Thickness of wireframe lines (studs)

export type TorusWireframe = {
	parts: { BasePart },
	majorRadius: number,
	minorRadius: number,
}

-- Generate a single wireframe line (thin cylinder) between two points
local function createWirePart(startPos: Vector3, endPos: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = "TorusWire"
	part.Archivable = false -- Exclude from undo history
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Shape = Enum.PartType.Cylinder

	-- Calculate position, size, and orientation
	local midPoint = (startPos + endPos) / 2
	local direction = endPos - startPos
	local length = direction.Magnitude

	-- Cylinder's length is along local X axis
	part.Size = Vector3.new(length, WIRE_THICKNESS, WIRE_THICKNESS)

	-- Orient the cylinder to point from start to end
	if length > 0.001 then
		local lookAt = CFrame.lookAt(midPoint, endPos)
		-- Rotate 90° around Y to align cylinder's X axis with the direction
		part.CFrame = lookAt * CFrame.Angles(0, math.rad(90), 0)
	else
		part.CFrame = CFrame.new(midPoint)
	end

	return part
end

-- Calculate a point on the torus surface
local function torusPoint(majorRadius: number, minorRadius: number, u: number, v: number): Vector3
	local x = (majorRadius + minorRadius * math.cos(v)) * math.cos(u)
	local y = minorRadius * math.sin(v)
	local z = (majorRadius + minorRadius * math.cos(v)) * math.sin(u)
	return Vector3.new(x, y, z)
end

--[[
	Generate a torus wireframe in LOCAL space (centered at origin)
	
	@param majorRadius - Distance from center to tube center
	@param minorRadius - Tube thickness (radius of tube cross-section)
	@param color - Color for the wireframe
	@param transparency - Transparency value (0 = opaque, 1 = invisible)
	@param ringSegments - Optional override for ring segments
	@param tubeSegments - Optional override for tube segments
	@return Array of Parts forming the wireframe
]]
function TorusMeshGenerator.createWireframe(
	majorRadius: number,
	minorRadius: number,
	color: Color3,
	transparency: number,
	ringSegments: number?,
	tubeSegments: number?
): { Part }
	local parts: { Part } = {}
	local rSegs = ringSegments or RING_SEGMENTS
	local tSegs = tubeSegments or TUBE_SEGMENTS

	-- Generate ring lines (circles around the tube at each ring position)
	for i = 0, rSegs - 1 do
		local u = (i / rSegs) * math.pi * 2

		-- Draw tube cross-section at this ring position
		for j = 0, tSegs - 1 do
			local v1 = (j / tSegs) * math.pi * 2
			local v2 = ((j + 1) / tSegs) * math.pi * 2

			local p1 = torusPoint(majorRadius, minorRadius, u, v1)
			local p2 = torusPoint(majorRadius, minorRadius, u, v2)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	-- Generate longitudinal lines (lines along the tube direction)
	for j = 0, tSegs - 1 do
		local v = (j / tSegs) * math.pi * 2

		-- Draw ring at this tube angle
		for i = 0, rSegs - 1 do
			local u1 = (i / rSegs) * math.pi * 2
			local u2 = ((i + 1) / rSegs) * math.pi * 2

			local p1 = torusPoint(majorRadius, minorRadius, u1, v)
			local p2 = torusPoint(majorRadius, minorRadius, u2, v)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	return parts
end

--[[
	Create a lighter wireframe with just the key structural lines
	Better for real-time preview during brush movement
	
	@param majorRadius - Distance from center to tube center
	@param minorRadius - Tube thickness
	@param color - Color for the wireframe
	@param transparency - Transparency value
	@return Array of Parts forming the wireframe
]]
function TorusMeshGenerator.createLightWireframe(majorRadius: number, minorRadius: number, color: Color3, transparency: number): { Part }
	local parts: { Part } = {}
	local rSegs = 16 -- Fewer segments for performance
	local tSegs = 8

	-- Only draw every other ring line for lighter preview
	for i = 0, rSegs - 1, 2 do
		local u = (i / rSegs) * math.pi * 2

		for j = 0, tSegs - 1 do
			local v1 = (j / tSegs) * math.pi * 2
			local v2 = ((j + 1) / tSegs) * math.pi * 2

			local p1 = torusPoint(majorRadius, minorRadius, u, v1)
			local p2 = torusPoint(majorRadius, minorRadius, u, v2)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	-- Draw main longitudinal lines (top, bottom, inner, outer)
	local keyAngles = { 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
	for _, v in ipairs(keyAngles) do
		for i = 0, rSegs - 1 do
			local u1 = (i / rSegs) * math.pi * 2
			local u2 = ((i + 1) / rSegs) * math.pi * 2

			local p1 = torusPoint(majorRadius, minorRadius, u1, v)
			local p2 = torusPoint(majorRadius, minorRadius, u2, v)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	return parts
end

--[[
	Update the CFrame of all wireframe parts to a new position/rotation
	
	@param parts - Array of wireframe parts
	@param cframe - New CFrame to apply
	@param majorRadius - Current major radius
	@param minorRadius - Current minor radius
]]
function TorusMeshGenerator.updateWireframeCFrame(parts: { Part }, cframe: CFrame, majorRadius: number, minorRadius: number)
	-- For CFrame updates, we need to recalculate all positions
	-- This is called every frame, so we need it to be fast
	-- The parts array structure: first half are ring circles, second half are longitudinal lines

	local rSegs = 16
	local tSegs = 8
	local partIndex = 1

	-- Update ring circles
	for i = 0, rSegs - 1, 2 do
		local u = (i / rSegs) * math.pi * 2

		for j = 0, tSegs - 1 do
			local v1 = (j / tSegs) * math.pi * 2
			local v2 = ((j + 1) / tSegs) * math.pi * 2

			local localP1 = torusPoint(majorRadius, minorRadius, u, v1)
			local localP2 = torusPoint(majorRadius, minorRadius, u, v2)

			local worldP1 = cframe:PointToWorldSpace(localP1)
			local worldP2 = cframe:PointToWorldSpace(localP2)

			local part = parts[partIndex]
			if part then
				local midPoint = (worldP1 + worldP2) / 2
				local direction = worldP2 - worldP1
				local length = direction.Magnitude

				part.Size = Vector3.new(length, WIRE_THICKNESS, WIRE_THICKNESS)
				if length > 0.001 then
					local lookAt = CFrame.lookAt(midPoint, worldP2)
					part.CFrame = lookAt * CFrame.Angles(0, math.rad(90), 0)
				end
			end
			partIndex = partIndex + 1
		end
	end

	-- Update longitudinal lines
	local keyAngles = { 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
	for _, v in ipairs(keyAngles) do
		for i = 0, rSegs - 1 do
			local u1 = (i / rSegs) * math.pi * 2
			local u2 = ((i + 1) / rSegs) * math.pi * 2

			local localP1 = torusPoint(majorRadius, minorRadius, u1, v)
			local localP2 = torusPoint(majorRadius, minorRadius, u2, v)

			local worldP1 = cframe:PointToWorldSpace(localP1)
			local worldP2 = cframe:PointToWorldSpace(localP2)

			local part = parts[partIndex]
			if part then
				local midPoint = (worldP1 + worldP2) / 2
				local direction = worldP2 - worldP1
				local length = direction.Magnitude

				part.Size = Vector3.new(length, WIRE_THICKNESS, WIRE_THICKNESS)
				if length > 0.001 then
					local lookAt = CFrame.lookAt(midPoint, worldP2)
					part.CFrame = lookAt * CFrame.Angles(0, math.rad(90), 0)
				end
			end
			partIndex = partIndex + 1
		end
	end
end

--[[
	Update colors of all wireframe parts
	
	@param parts - Array of wireframe parts
	@param color - New color to apply
]]
function TorusMeshGenerator.updateWireframeColor(parts: { Part }, color: Color3)
	for _, part in ipairs(parts) do
		part.Color = color
	end
end

--[[
	Parent all wireframe parts to a container
	
	@param parts - Array of wireframe parts
	@param parent - Parent instance
]]
function TorusMeshGenerator.parentWireframe(parts: { Part }, parent: Instance)
	for _, part in ipairs(parts) do
		part.Parent = parent
	end
end

--[[
	Destroy all wireframe parts
	
	@param parts - Array of wireframe parts
]]
function TorusMeshGenerator.destroyWireframe(parts: { Part })
	for _, part in ipairs(parts) do
		part:Destroy()
	end
end

return TorusMeshGenerator
