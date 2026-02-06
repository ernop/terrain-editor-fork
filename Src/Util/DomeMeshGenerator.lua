--!strict
--[[
	DomeMeshGenerator.lua - Generates dome/hemisphere wireframe geometry
	
	Creates a wireframe visualization of a hemisphere (half-sphere).
	Supports both upward-facing domes (regular Dome) and forward-facing domes (RotatedDome/Arch).
	
	Hemisphere parametric equations (top half, Y >= 0):
	x = rx * sin(φ) * cos(θ)
	y = ry * cos(φ)
	z = rz * sin(φ) * sin(θ)
	
	Where:
	- rx, ry, rz = radii for each axis (ellipsoid support)
	- φ (phi) = angle from top pole (0 to π/2 for hemisphere)
	- θ (theta) = angle around the vertical axis (0 to 2π)
	
	For forward-facing dome (RotatedDome), we rotate the geometry 90° around X
	so it faces forward (Z+) instead of up (Y+).
]]

local DomeMeshGenerator = {}

-- Configuration
local THETA_SEGMENTS = 16 -- Segments around the dome (horizontal circles)
local PHI_SEGMENTS = 8 -- Segments from pole to equator (vertical arcs)
local WIRE_THICKNESS = 0.08 -- Thickness of wireframe lines (studs)

export type DomeWireframe = {
	parts: { BasePart },
	radiusX: number,
	radiusY: number,
	radiusZ: number,
	isRotated: boolean,
}

-- Generate a single wireframe line (thin cylinder) between two points
local function createWirePart(startPos: Vector3, endPos: Vector3, color: Color3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = "DomeWire"
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

-- Calculate a point on the hemisphere surface (top half, Y >= 0)
-- phi: 0 = top pole, π/2 = equator
-- theta: angle around vertical axis
local function hemispherePoint(radiusX: number, radiusY: number, radiusZ: number, phi: number, theta: number, isRotated: boolean): Vector3
	local sinPhi = math.sin(phi)
	local cosPhi = math.cos(phi)
	local sinTheta = math.sin(theta)
	local cosTheta = math.cos(theta)

	if isRotated then
		-- Forward-facing dome (Z >= 0): rotate the standard hemisphere 90° around X
		-- Standard: (sinPhi*cosTheta, cosPhi, sinPhi*sinTheta)
		-- After 90° X rotation: (x, -z, y) -> (sinPhi*cosTheta, -sinPhi*sinTheta, cosPhi)
		-- This makes the dome open toward +Z
		return Vector3.new(radiusX * sinPhi * cosTheta, radiusY * sinPhi * sinTheta, radiusZ * cosPhi)
	else
		-- Standard upward-facing dome (Y >= 0)
		return Vector3.new(radiusX * sinPhi * cosTheta, radiusY * cosPhi, radiusZ * sinPhi * sinTheta)
	end
end

--[[
	Generate a dome wireframe in LOCAL space (centered at origin)
	
	@param radiusX - X radius
	@param radiusY - Y radius (height for standard dome, or vertical extent for rotated)
	@param radiusZ - Z radius (depth for rotated dome)
	@param isRotated - true for forward-facing dome (RotatedDome), false for upward-facing (Dome)
	@param color - Color for the wireframe
	@param transparency - Transparency value (0 = opaque, 1 = invisible)
	@return Array of Parts forming the wireframe
]]
function DomeMeshGenerator.createWireframe(
	radiusX: number,
	radiusY: number,
	radiusZ: number,
	isRotated: boolean,
	color: Color3,
	transparency: number
): { Part }
	local parts: { Part } = {}

	-- Draw horizontal circles (latitude lines) at different heights
	for i = 0, PHI_SEGMENTS do
		local phi = (i / PHI_SEGMENTS) * (math.pi / 2) -- 0 to π/2

		-- Draw circle at this latitude
		for j = 0, THETA_SEGMENTS - 1 do
			local theta1 = (j / THETA_SEGMENTS) * math.pi * 2
			local theta2 = ((j + 1) / THETA_SEGMENTS) * math.pi * 2

			local p1 = hemispherePoint(radiusX, radiusY, radiusZ, phi, theta1, isRotated)
			local p2 = hemispherePoint(radiusX, radiusY, radiusZ, phi, theta2, isRotated)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	-- Draw vertical arcs (longitude lines) from pole to equator
	local numMeridians = 8 -- Number of vertical lines
	for j = 0, numMeridians - 1 do
		local theta = (j / numMeridians) * math.pi * 2

		-- Draw arc from pole to equator
		for i = 0, PHI_SEGMENTS - 1 do
			local phi1 = (i / PHI_SEGMENTS) * (math.pi / 2)
			local phi2 = ((i + 1) / PHI_SEGMENTS) * (math.pi / 2)

			local p1 = hemispherePoint(radiusX, radiusY, radiusZ, phi1, theta, isRotated)
			local p2 = hemispherePoint(radiusX, radiusY, radiusZ, phi2, theta, isRotated)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	-- Draw the flat base circle (equator) with a thicker line for emphasis
	-- This helps visualize where the dome is "cut"
	for j = 0, THETA_SEGMENTS - 1 do
		local theta1 = (j / THETA_SEGMENTS) * math.pi * 2
		local theta2 = ((j + 1) / THETA_SEGMENTS) * math.pi * 2

		local p1 = hemispherePoint(radiusX, radiusY, radiusZ, math.pi / 2, theta1, isRotated)
		local p2 = hemispherePoint(radiusX, radiusY, radiusZ, math.pi / 2, theta2, isRotated)

		-- Base circle already drawn in latitude lines, skip duplicate
	end

	return parts
end

--[[
	Create a lighter wireframe with just the key structural lines
	Better for real-time preview during brush movement
	
	@param radiusX - X radius
	@param radiusY - Y radius
	@param radiusZ - Z radius
	@param isRotated - true for forward-facing dome
	@param color - Color for the wireframe
	@param transparency - Transparency value
	@return Array of Parts forming the wireframe
]]
function DomeMeshGenerator.createLightWireframe(
	radiusX: number,
	radiusY: number,
	radiusZ: number,
	isRotated: boolean,
	color: Color3,
	transparency: number
): { Part }
	local parts: { Part } = {}
	local thetaSegs = 12
	local phiSegs = 4

	-- Draw just 3 horizontal circles: near top, middle, and equator
	local keyPhis = { 0.2, 0.5, 1.0 } -- Fractions of π/2
	for _, phiFrac in ipairs(keyPhis) do
		local phi = phiFrac * (math.pi / 2)

		for j = 0, thetaSegs - 1 do
			local theta1 = (j / thetaSegs) * math.pi * 2
			local theta2 = ((j + 1) / thetaSegs) * math.pi * 2

			local p1 = hemispherePoint(radiusX, radiusY, radiusZ, phi, theta1, isRotated)
			local p2 = hemispherePoint(radiusX, radiusY, radiusZ, phi, theta2, isRotated)

			local wire = createWirePart(p1, p2, color, transparency)
			table.insert(parts, wire)
		end
	end

	-- Draw 4 vertical arcs (cardinal directions)
	local keyThetas = { 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
	for _, theta in ipairs(keyThetas) do
		for i = 0, phiSegs - 1 do
			local phi1 = (i / phiSegs) * (math.pi / 2)
			local phi2 = ((i + 1) / phiSegs) * (math.pi / 2)

			local p1 = hemispherePoint(radiusX, radiusY, radiusZ, phi1, theta, isRotated)
			local p2 = hemispherePoint(radiusX, radiusY, radiusZ, phi2, theta, isRotated)

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
	@param radiusX - Current X radius
	@param radiusY - Current Y radius
	@param radiusZ - Current Z radius
	@param isRotated - Whether this is a rotated dome
]]
function DomeMeshGenerator.updateWireframeCFrame(
	parts: { Part },
	cframe: CFrame,
	radiusX: number,
	radiusY: number,
	radiusZ: number,
	isRotated: boolean
)
	local thetaSegs = 12
	local phiSegs = 4
	local partIndex = 1

	-- Update horizontal circles
	local keyPhis = { 0.2, 0.5, 1.0 }
	for _, phiFrac in ipairs(keyPhis) do
		local phi = phiFrac * (math.pi / 2)

		for j = 0, thetaSegs - 1 do
			local theta1 = (j / thetaSegs) * math.pi * 2
			local theta2 = ((j + 1) / thetaSegs) * math.pi * 2

			local localP1 = hemispherePoint(radiusX, radiusY, radiusZ, phi, theta1, isRotated)
			local localP2 = hemispherePoint(radiusX, radiusY, radiusZ, phi, theta2, isRotated)

			local worldP1 = cframe:PointToWorldSpace(localP1)
			local worldP2 = cframe:PointToWorldSpace(localP2)

			local part = parts[partIndex]
			if part then
				local midPoint = (worldP1 + worldP2) / 2
				local length = (worldP2 - worldP1).Magnitude

				part.Size = Vector3.new(length, WIRE_THICKNESS, WIRE_THICKNESS)
				if length > 0.001 then
					local lookAt = CFrame.lookAt(midPoint, worldP2)
					part.CFrame = lookAt * CFrame.Angles(0, math.rad(90), 0)
				end
			end
			partIndex = partIndex + 1
		end
	end

	-- Update vertical arcs
	local keyThetas = { 0, math.pi * 0.5, math.pi, math.pi * 1.5 }
	for _, theta in ipairs(keyThetas) do
		for i = 0, phiSegs - 1 do
			local phi1 = (i / phiSegs) * (math.pi / 2)
			local phi2 = ((i + 1) / phiSegs) * (math.pi / 2)

			local localP1 = hemispherePoint(radiusX, radiusY, radiusZ, phi1, theta, isRotated)
			local localP2 = hemispherePoint(radiusX, radiusY, radiusZ, phi2, theta, isRotated)

			local worldP1 = cframe:PointToWorldSpace(localP1)
			local worldP2 = cframe:PointToWorldSpace(localP2)

			local part = parts[partIndex]
			if part then
				local midPoint = (worldP1 + worldP2) / 2
				local length = (worldP2 - worldP1).Magnitude

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
function DomeMeshGenerator.updateWireframeColor(parts: { Part }, color: Color3)
	for _, part in ipairs(parts) do
		part.Color = color
	end
end

--[[
	Parent all wireframe parts to a container
	
	@param parts - Array of wireframe parts
	@param parent - Parent instance
]]
function DomeMeshGenerator.parentWireframe(parts: { Part }, parent: Instance)
	for _, part in ipairs(parts) do
		part.Parent = parent
	end
end

--[[
	Destroy all wireframe parts
	
	@param parts - Array of wireframe parts
]]
function DomeMeshGenerator.destroyWireframe(parts: { Part })
	for _, part in ipairs(parts) do
		part:Destroy()
	end
end

return DomeMeshGenerator
