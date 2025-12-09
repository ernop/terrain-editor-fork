--!strict
-- Advanced bridge path generation with terrain awareness and multiple curves

local BridgePathGenerator = {}

export type Curve = {
	type: string, -- "sin", "cos", "tan", "combined"
	amplitude: number,
	frequency: number,
	phase: number,
	offset: Vector3, -- Per-curve offset
	verticalBias: number, -- How much this curve affects vertical movement
	horizontalBias: number, -- How much this curve affects horizontal movement
}

export type PathPoint = {
	position: Vector3,
	tangent: Vector3,
}

-- Generate a random curve with varied parameters
function BridgePathGenerator.generateRandomCurve(): Curve
	local curveTypes = { "sin", "cos", "combined" }
	local curveType = curveTypes[math.random(1, #curveTypes)]
	
	return {
		type = curveType,
		amplitude = math.random(50, 200) / 100, -- 0.5 to 2.0
		frequency = math.random(20, 80) / 10, -- 2.0 to 8.0
		phase = math.random(0, 628) / 100, -- 0 to 2π
		offset = Vector3.new(
			math.random(-100, 100) / 100,
			math.random(-50, 50) / 100,
			math.random(-100, 100) / 100
		),
		verticalBias = math.random(30, 100) / 100,
		horizontalBias = math.random(30, 100) / 100,
	}
end

-- Get terrain height at a position (raycast down)
function BridgePathGenerator.getTerrainHeight(terrain: Terrain, position: Vector3): number?
	local rayOrigin = position + Vector3.new(0, 100, 0)
	local rayDirection = Vector3.new(0, -200, 0)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
	raycastParams.FilterDescendantsInstances = { terrain }
	
	local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	if result and result.Instance == terrain then
		return result.Position.Y
	end
	return nil
end

-- Check if position is near terrain (for "leading up to terrain" behavior)
function BridgePathGenerator.isNearTerrain(terrain: Terrain, position: Vector3, searchRadius: number): boolean
	local terrainHeight = BridgePathGenerator.getTerrainHeight(terrain, position)
	if not terrainHeight then
		return false
	end
	local distance = math.abs(position.Y - terrainHeight)
	return distance < searchRadius
end

-- Find nearby terrain peaks/features to guide path toward
function BridgePathGenerator.findNearbyTerrainFeatures(
	terrain: Terrain,
	position: Vector3,
	searchRadius: number,
	maxFeatures: number
): { Vector3 }
	local features: { Vector3 } = {}
	local stepSize = searchRadius / 10
	
	for x = -searchRadius, searchRadius, stepSize do
		for z = -searchRadius, searchRadius, stepSize do
			local checkPos = position + Vector3.new(x, 0, z)
			local terrainHeight = BridgePathGenerator.getTerrainHeight(terrain, checkPos)
			if terrainHeight then
				local featurePos = Vector3.new(checkPos.X, terrainHeight + 5, checkPos.Z)
				table.insert(features, featurePos)
				if #features >= maxFeatures then
					break
				end
			end
		end
		if #features >= maxFeatures then
			break
		end
	end
	
	return features
end

-- Evaluate a curve at parameter t (0 to 1)
function BridgePathGenerator.evaluateCurve(curve: Curve, t: number): Vector3
	local value = 0.0
	
	if curve.type == "sin" then
		value = math.sin(t * math.pi * 2 * curve.frequency + curve.phase)
	elseif curve.type == "cos" then
		value = math.cos(t * math.pi * 2 * curve.frequency + curve.phase)
	elseif curve.type == "combined" then
		value = math.sin(t * math.pi * 2 * curve.frequency + curve.phase) * 0.6
			+ math.cos(t * math.pi * 2 * curve.frequency * 1.5 + curve.phase * 0.7) * 0.4
	end
	
	local vertical = value * curve.amplitude * curve.verticalBias
	local horizontal = value * curve.amplitude * curve.horizontalBias
	
	return Vector3.new(
		horizontal + curve.offset.X,
		vertical + curve.offset.Y,
		horizontal * 0.7 + curve.offset.Z
	)
end

-- Generate a meandering path from start to end using multiple curves
function BridgePathGenerator.generateMeanderingPath(
	startPoint: Vector3,
	endPoint: Vector3,
	curves: { Curve },
	terrain: Terrain?,
	numSteps: number,
	terrainAwareness: boolean
): { PathPoint }
	local path: { PathPoint } = {}
	local distance = (endPoint - startPoint).Magnitude
	local pathDir = (endPoint - startPoint).Unit
	local perpDir = Vector3.new(-pathDir.Z, 0, pathDir.X)
	local upDir = Vector3.new(0, 1, 0)
	
	local baseArcHeight = distance * 0.2 -- Base arc height
	
	for i = 0, numSteps do
		local t = i / numSteps
		
		-- Base linear interpolation
		local basePos = startPoint:Lerp(endPoint, t)
		
		-- Apply all curves
		local curveOffset = Vector3.new(0, 0, 0)
		for _, curve in ipairs(curves) do
			local curveValue = BridgePathGenerator.evaluateCurve(curve, t)
			curveOffset = curveOffset + curveValue
		end
		
		-- Normalize curve offset by number of curves
		if #curves > 0 then
			curveOffset = curveOffset / #curves
		end
		
		-- Apply base arc
		local arcHeight = math.sin(t * math.pi) * baseArcHeight
		
		-- Combine offsets
		local verticalOffset = Vector3.new(0, arcHeight + curveOffset.Y * distance * 0.3, 0)
		-- Calculate perpendicular direction for Z offset (cross product of pathDir and upDir)
		local perpDirZ = pathDir:Cross(upDir)
		if perpDirZ.Magnitude < 0.001 then
			-- Fallback if vectors are parallel
			perpDirZ = Vector3.new(0, 0, 1)
		else
			perpDirZ = perpDirZ.Unit
		end
		local horizontalOffset = perpDir * (curveOffset.X * distance * 0.2) 
			+ perpDirZ * (curveOffset.Z * distance * 0.2)
		
		local finalPos = basePos + verticalOffset + horizontalOffset
		
		-- Terrain awareness: adjust height to follow terrain or avoid it
		if terrainAwareness and terrain then
			local terrainHeight = BridgePathGenerator.getTerrainHeight(terrain, finalPos)
			if terrainHeight then
				-- Try to lead up to terrain features
				local distanceToTerrain = math.abs(finalPos.Y - terrainHeight)
				if distanceToTerrain < 20 then
					-- Close to terrain - adjust to go slightly above
					finalPos = Vector3.new(finalPos.X, math.max(finalPos.Y, terrainHeight + 5), finalPos.Z)
				elseif distanceToTerrain > 50 then
					-- Far from terrain - might want to curve toward it
					local nearbyFeatures = BridgePathGenerator.findNearbyTerrainFeatures(terrain, finalPos, 30, 3)
					if #nearbyFeatures > 0 then
						-- Gently curve toward nearest feature
						local nearestFeature = nearbyFeatures[1]
						local toFeature = (nearestFeature - finalPos).Unit
						finalPos = finalPos + toFeature * (distance * 0.05 * (1 - t) * t) -- Stronger in middle
					end
				end
			end
		end
		
		-- Calculate tangent (direction) for smooth path
		local tangent = pathDir
		if i > 0 then
			tangent = (finalPos - path[#path].position).Unit
		elseif i < numSteps then
			-- Will be updated next iteration
		end
		
		table.insert(path, {
			position = finalPos,
			tangent = tangent,
		})
	end
	
	-- Smooth tangents
	for i = 2, #path - 1 do
		local prev = path[i - 1].position
		local next = path[i + 1].position
		path[i].tangent = (next - prev).Unit
	end
	
	return path
end

-- Generate random curves for Mega Meander mode
function BridgePathGenerator.generateRandomCurves(count: number): { Curve }
	local curves: { Curve } = {}
	for i = 1, count do
		table.insert(curves, BridgePathGenerator.generateRandomCurve())
	end
	return curves
end

return BridgePathGenerator


