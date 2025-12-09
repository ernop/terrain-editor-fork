--[[
	TerrainPowers - Player enhancement script
	Powers: Fly, Speed, Jump, Teleport (hold 1s), Dig Terrain
	Terrain-styled UI in bottom-right corner
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- State
local powers = {
	fly = false,
	hyperspeed = false,
	superJump = false,
	teleport = false,
	dig = false,
}

local flyBodyVelocity = nil
local flyBodyGyro = nil
local originalWalkSpeed = 16
local originalJumpPower = 50

-- Constants
local FLY_SPEED = 160
local HYPERSPEED_MULTIPLIER = 4
local SUPER_JUMP_POWER = 100
local TELEPORT_HOLD_TIME = 1
local DIG_RADIUS = 8

-- Material colors for terrain detection display
local MATERIAL_COLORS = {
	[Enum.Material.Grass] = { color = Color3.fromRGB(76, 153, 76), name = "Grass" },
	[Enum.Material.Sand] = { color = Color3.fromRGB(194, 178, 128), name = "Sand" },
	[Enum.Material.Rock] = { color = Color3.fromRGB(127, 127, 127), name = "Rock" },
	[Enum.Material.Ground] = { color = Color3.fromRGB(139, 105, 73), name = "Ground" },
	[Enum.Material.Snow] = { color = Color3.fromRGB(235, 245, 255), name = "Snow" },
	[Enum.Material.Ice] = { color = Color3.fromRGB(180, 220, 245), name = "Ice" },
	[Enum.Material.Glacier] = { color = Color3.fromRGB(200, 230, 255), name = "Glacier" },
	[Enum.Material.Water] = { color = Color3.fromRGB(66, 135, 245), name = "Water" },
	[Enum.Material.Mud] = { color = Color3.fromRGB(90, 70, 50), name = "Mud" },
	[Enum.Material.Slate] = { color = Color3.fromRGB(88, 101, 113), name = "Slate" },
	[Enum.Material.Concrete] = { color = Color3.fromRGB(150, 150, 150), name = "Concrete" },
	[Enum.Material.Brick] = { color = Color3.fromRGB(170, 85, 70), name = "Brick" },
	[Enum.Material.Cobblestone] = { color = Color3.fromRGB(130, 130, 130), name = "Cobblestone" },
	[Enum.Material.Asphalt] = { color = Color3.fromRGB(60, 60, 60), name = "Asphalt" },
	[Enum.Material.Pavement] = { color = Color3.fromRGB(140, 140, 140), name = "Pavement" },
	[Enum.Material.Basalt] = { color = Color3.fromRGB(50, 50, 55), name = "Basalt" },
	[Enum.Material.CrackedLava] = { color = Color3.fromRGB(255, 89, 38), name = "Cracked Lava" },
	[Enum.Material.Salt] = { color = Color3.fromRGB(240, 240, 240), name = "Salt" },
	[Enum.Material.Sandstone] = { color = Color3.fromRGB(200, 160, 120), name = "Sandstone" },
	[Enum.Material.Limestone] = { color = Color3.fromRGB(220, 210, 190), name = "Limestone" },
	[Enum.Material.LeafyGrass] = { color = Color3.fromRGB(60, 140, 60), name = "Leafy Grass" },
	[Enum.Material.WoodPlanks] = { color = Color3.fromRGB(140, 100, 60), name = "Wood Planks" },
	[Enum.Material.Air] = { color = Color3.fromRGB(80, 80, 80), name = "Air" },
}

-- Button configs (first letter = keyboard shortcut)
local BUTTON_CONFIGS = {
	{ key = "fly", label = "FLY", color = Color3.fromRGB(66, 135, 245), hotkey = Enum.KeyCode.F },
	{ key = "hyperspeed", label = "SPEED", color = Color3.fromRGB(255, 89, 38), hotkey = Enum.KeyCode.S },
	{ key = "superJump", label = "JUMP", color = Color3.fromRGB(76, 153, 76), hotkey = Enum.KeyCode.J },
	{ key = "teleport", label = "WARP", color = Color3.fromRGB(180, 100, 255), hotkey = Enum.KeyCode.W },
	{ key = "dig", label = "DIG", color = Color3.fromRGB(139, 105, 73), hotkey = Enum.KeyCode.D },
}

-- Sound effects
local function playSound(id, volume, pitch)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	return sound
end

-- Create the UI
local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TerrainPowersUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = player:WaitForChild("PlayerGui")

	-- Terrain detector panel (compact)
	local terrainDetector = Instance.new("Frame")
	terrainDetector.Name = "TerrainDetector"
	terrainDetector.Size = UDim2.new(0, 140, 0, 40)
	terrainDetector.Position = UDim2.new(1, -156, 1, -280) -- Above powers container
	terrainDetector.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
	terrainDetector.BackgroundTransparency = 0.2
	terrainDetector.BorderSizePixel = 0
	terrainDetector.Parent = screenGui

	local detectorCorner = Instance.new("UICorner")
	detectorCorner.CornerRadius = UDim.new(0, 6)
	detectorCorner.Parent = terrainDetector

	-- Material color swatch
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.new(0, 28, 0, 28)
	swatch.Position = UDim2.new(0, 6, 0.5, -14)
	swatch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	swatch.BorderSizePixel = 0
	swatch.Parent = terrainDetector

	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(0, 4)
	swatchCorner.Parent = swatch

	-- Material name
	local materialLabel = Instance.new("TextLabel")
	materialLabel.Name = "MaterialLabel"
	materialLabel.Size = UDim2.new(1, -44, 1, 0)
	materialLabel.Position = UDim2.new(0, 40, 0, 0)
	materialLabel.BackgroundTransparency = 1
	materialLabel.Text = "Air"
	materialLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	materialLabel.TextSize = 14
	materialLabel.Font = Enum.Font.GothamBold
	materialLabel.TextXAlignment = Enum.TextXAlignment.Left
	materialLabel.Parent = terrainDetector

	-- Powers container (simplified horizontal strip)
	local container = Instance.new("Frame")
	container.Name = "PowersContainer"
	container.Size = UDim2.new(0, 140, 0, 210) -- Taller for bigger buttons
	container.Position = UDim2.new(1, -156, 1, -222)
	container.BackgroundColor3 = Color3.fromRGB(15, 18, 22)
	container.BackgroundTransparency = 0.2
	container.BorderSizePixel = 0
	container.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	-- Button list
	local buttonList = Instance.new("Frame")
	buttonList.Name = "ButtonList"
	buttonList.Size = UDim2.new(1, -12, 1, -12)
	buttonList.Position = UDim2.new(0, 6, 0, 6)
	buttonList.BackgroundTransparency = 1
	buttonList.Parent = container

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = buttonList

	-- Teleport countdown overlay
	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "CountdownFrame"
	countdownFrame.Size = UDim2.new(0, 120, 0, 120)
	countdownFrame.Position = UDim2.new(0.5, -60, 0.5, -60)
	countdownFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	countdownFrame.BackgroundTransparency = 0.5
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Visible = false
	countdownFrame.Parent = screenGui

	local countdownCorner = Instance.new("UICorner")
	countdownCorner.CornerRadius = UDim.new(0, 60)
	countdownCorner.Parent = countdownFrame

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "CountdownLabel"
	countdownLabel.Size = UDim2.new(1, 0, 1, 0)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = "3"
	countdownLabel.TextColor3 = Color3.fromRGB(180, 100, 255)
	countdownLabel.TextSize = 56
	countdownLabel.Font = Enum.Font.GothamBlack
	countdownLabel.Parent = countdownFrame

	local countdownRing = Instance.new("UIStroke")
	countdownRing.Color = Color3.fromRGB(180, 100, 255)
	countdownRing.Thickness = 4
	countdownRing.Parent = countdownFrame

	return screenGui, buttonList, swatch, materialLabel, countdownFrame, countdownLabel
end

-- Create simple toggle button
local function createPowerButton(parent, config, index)
	local button = Instance.new("TextButton")
	button.Name = config.key .. "Button"
	button.Size = UDim2.new(1, 0, 0, 36) -- Taller buttons
	button.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
	button.BorderSizePixel = 0
	button.LayoutOrder = index
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	-- Color bar (thicker when on)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(0, 4, 1, -8)
	bar.Position = UDim2.new(0, 4, 0, 4)
	bar.BackgroundColor3 = config.color
	bar.BackgroundTransparency = 0.5
	bar.BorderSizePixel = 0
	bar.Parent = button

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 2)
	barCorner.Parent = bar

	-- Hotkey indicator (shows the shortcut key)
	local hotkeyLabel = Instance.new("TextLabel")
	hotkeyLabel.Name = "Hotkey"
	hotkeyLabel.Size = UDim2.new(0, 20, 0, 20)
	hotkeyLabel.Position = UDim2.new(0, 14, 0.5, -10)
	hotkeyLabel.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
	hotkeyLabel.BackgroundTransparency = 0.5
	hotkeyLabel.Text = config.label:sub(1, 1) -- First letter
	hotkeyLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	hotkeyLabel.TextSize = 14
	hotkeyLabel.Font = Enum.Font.GothamBlack
	hotkeyLabel.Parent = button

	local hotkeyCorner = Instance.new("UICorner")
	hotkeyCorner.CornerRadius = UDim.new(0, 4)
	hotkeyCorner.Parent = hotkeyLabel

	-- Main label (bigger text)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -60, 1, 0)
	label.Position = UDim2.new(0, 40, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = config.label
	label.TextColor3 = Color3.fromRGB(200, 200, 200)
	label.TextSize = 18 -- Bigger text
	label.Font = Enum.Font.GothamBlack
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = button

	-- Status indicator (larger, more visible)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, 12, 0, 12)
	dot.Position = UDim2.new(1, -20, 0.5, -6)
	dot.BackgroundColor3 = Color3.fromRGB(50, 55, 65)
	dot.BorderSizePixel = 0
	dot.Parent = button

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	return button, bar, dot, config.color, label, hotkeyLabel
end

-- Power implementations
local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

local function getHumanoid()
	local char = getCharacter()
	return char:FindFirstChildOfClass("Humanoid")
end

local function getRootPart()
	local char = getCharacter()
	return char:FindFirstChild("HumanoidRootPart")
end

-- Terrain weapon definitions
local TERRAIN_WEAPONS = {
	[Enum.Material.Grass] = {
		name = "Thorn Whip",
		color = Color3.fromRGB(60, 120, 40),
		projectileType = "beam",
		damage = 25,
		sound = 12222216,
		trailColor = Color3.fromRGB(80, 160, 60),
	},
	[Enum.Material.Sand] = {
		name = "Sand Blast",
		color = Color3.fromRGB(220, 190, 130),
		projectileType = "spray",
		damage = 15,
		sound = 142082166,
		trailColor = Color3.fromRGB(240, 210, 150),
	},
	[Enum.Material.Rock] = {
		name = "Boulder Launcher",
		color = Color3.fromRGB(100, 100, 100),
		projectileType = "ball",
		damage = 40,
		sound = 142082166,
		trailColor = Color3.fromRGB(130, 130, 130),
	},
	[Enum.Material.Ground] = {
		name = "Mud Cannon",
		color = Color3.fromRGB(100, 75, 50),
		projectileType = "ball",
		damage = 20,
		sound = 1369158539,
		trailColor = Color3.fromRGB(120, 90, 60),
	},
	[Enum.Material.Snow] = {
		name = "Frost Ray",
		color = Color3.fromRGB(220, 240, 255),
		projectileType = "beam",
		damage = 20,
		sound = 138090596,
		trailColor = Color3.fromRGB(200, 230, 255),
	},
	[Enum.Material.Ice] = {
		name = "Ice Spike",
		color = Color3.fromRGB(180, 220, 245),
		projectileType = "spike",
		damage = 35,
		sound = 138090596,
		trailColor = Color3.fromRGB(200, 240, 255),
	},
	[Enum.Material.Glacier] = {
		name = "Cryo Beam",
		color = Color3.fromRGB(150, 200, 255),
		projectileType = "beam",
		damage = 30,
		sound = 138090596,
		trailColor = Color3.fromRGB(180, 220, 255),
	},
	[Enum.Material.Water] = {
		name = "Hydro Jet",
		color = Color3.fromRGB(50, 120, 220),
		projectileType = "stream",
		damage = 18,
		sound = 142082166,
		trailColor = Color3.fromRGB(80, 150, 240),
	},
	[Enum.Material.Mud] = {
		name = "Sludge Bomb",
		color = Color3.fromRGB(70, 55, 40),
		projectileType = "ball",
		damage = 22,
		sound = 1369158539,
		trailColor = Color3.fromRGB(90, 70, 50),
	},
	[Enum.Material.Slate] = {
		name = "Shard Launcher",
		color = Color3.fromRGB(80, 90, 100),
		projectileType = "shards",
		damage = 28,
		sound = 12222216,
		trailColor = Color3.fromRGB(100, 110, 120),
	},
	[Enum.Material.Concrete] = {
		name = "Rubble Gun",
		color = Color3.fromRGB(140, 140, 140),
		projectileType = "shards",
		damage = 25,
		sound = 142082166,
		trailColor = Color3.fromRGB(160, 160, 160),
	},
	[Enum.Material.Brick] = {
		name = "Brick Barrage",
		color = Color3.fromRGB(170, 85, 70),
		projectileType = "shards",
		damage = 30,
		sound = 142082166,
		trailColor = Color3.fromRGB(190, 100, 80),
	},
	[Enum.Material.Cobblestone] = {
		name = "Stone Scatter",
		color = Color3.fromRGB(120, 120, 120),
		projectileType = "shards",
		damage = 26,
		sound = 142082166,
		trailColor = Color3.fromRGB(140, 140, 140),
	},
	[Enum.Material.Asphalt] = {
		name = "Tar Spray",
		color = Color3.fromRGB(40, 40, 45),
		projectileType = "spray",
		damage = 15,
		sound = 1369158539,
		trailColor = Color3.fromRGB(60, 60, 65),
	},
	[Enum.Material.Pavement] = {
		name = "Crack Wave",
		color = Color3.fromRGB(130, 130, 130),
		projectileType = "wave",
		damage = 22,
		sound = 142082166,
		trailColor = Color3.fromRGB(150, 150, 150),
	},
	[Enum.Material.Basalt] = {
		name = "Dark Stone",
		color = Color3.fromRGB(35, 35, 40),
		projectileType = "ball",
		damage = 38,
		sound = 142082166,
		trailColor = Color3.fromRGB(50, 50, 60),
	},
	[Enum.Material.CrackedLava] = {
		name = "Lava Burst",
		color = Color3.fromRGB(255, 100, 30),
		projectileType = "fireball",
		damage = 45,
		sound = 138090596,
		trailColor = Color3.fromRGB(255, 150, 50),
	},
	[Enum.Material.Salt] = {
		name = "Crystal Spray",
		color = Color3.fromRGB(250, 250, 250),
		projectileType = "shards",
		damage = 24,
		sound = 138090596,
		trailColor = Color3.fromRGB(255, 255, 255),
	},
	[Enum.Material.Sandstone] = {
		name = "Desert Wind",
		color = Color3.fromRGB(200, 160, 110),
		projectileType = "spray",
		damage = 18,
		sound = 142082166,
		trailColor = Color3.fromRGB(220, 180, 130),
	},
	[Enum.Material.Limestone] = {
		name = "Fossil Shards",
		color = Color3.fromRGB(230, 220, 200),
		projectileType = "shards",
		damage = 26,
		sound = 12222216,
		trailColor = Color3.fromRGB(240, 230, 210),
	},
	[Enum.Material.LeafyGrass] = {
		name = "Jungle Fury",
		color = Color3.fromRGB(50, 130, 50),
		projectileType = "stream",
		damage = 22,
		sound = 12222216,
		trailColor = Color3.fromRGB(70, 150, 70),
	},
	[Enum.Material.WoodPlanks] = {
		name = "Splinter Shot",
		color = Color3.fromRGB(140, 100, 60),
		projectileType = "shards",
		damage = 28,
		sound = 12222216,
		trailColor = Color3.fromRGB(160, 120, 80),
	},
}

-- Current weapon state (defaults to Grass, never Air)
local currentWeaponMaterial = Enum.Material.Grass
local terrainTool = nil

-- Damage humanoids in radius
local function damageInRadius(position, radius, damage, excludePlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= excludePlayer and p.Character then
			local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
			local rootPart = p.Character:FindFirstChild("HumanoidRootPart")
			if humanoid and rootPart then
				local dist = (rootPart.Position - position).Magnitude
				if dist <= radius then
					humanoid:TakeDamage(damage * (1 - dist / radius * 0.5))
				end
			end
		end
	end
	-- Also damage NPCs
	for _, model in ipairs(workspace:GetDescendants()) do
		if model:IsA("Humanoid") and model.Parent ~= player.Character then
			local rootPart = model.Parent:FindFirstChild("HumanoidRootPart") or model.Parent:FindFirstChild("Torso")
			if rootPart then
				local dist = (rootPart.Position - position).Magnitude
				if dist <= radius then
					model:TakeDamage(damage * (1 - dist / radius * 0.5))
				end
			end
		end
	end
end

-- Create projectile effects
local function createProjectile(startPos, targetPos, weaponDef)
	local direction = (targetPos - startPos).Unit
	local distance = math.min((targetPos - startPos).Magnitude, 150)

	if weaponDef.projectileType == "ball" or weaponDef.projectileType == "fireball" then
		-- Single projectile ball
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(2, 2, 2)
		ball.Color = weaponDef.color
		ball.Material = weaponDef.projectileType == "fireball" and Enum.Material.Neon or Enum.Material.SmoothPlastic
		ball.Anchored = false
		ball.CanCollide = false
		ball.Position = startPos
		ball.Parent = workspace

		-- Trail
		local attachment0 = Instance.new("Attachment", ball)
		local attachment1 = Instance.new("Attachment", ball)
		attachment1.Position = Vector3.new(0, 0, -1)
		local trail = Instance.new("Trail")
		trail.Attachment0 = attachment0
		trail.Attachment1 = attachment1
		trail.Color = ColorSequence.new(weaponDef.trailColor)
		trail.Lifetime = 0.3
		trail.Parent = ball

		-- Velocity
		local velocity = Instance.new("BodyVelocity")
		velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		velocity.Velocity = direction * 120
		velocity.Parent = ball

		-- Hit detection
		ball.Touched:Connect(function(hit)
			if hit:IsDescendantOf(player.Character) then
				return
			end

			-- Explosion effect
			local explosion = Instance.new("Part")
			explosion.Shape = Enum.PartType.Ball
			explosion.Size = Vector3.new(1, 1, 1)
			explosion.Color = weaponDef.color
			explosion.Material = Enum.Material.Neon
			explosion.Anchored = true
			explosion.CanCollide = false
			explosion.Position = ball.Position
			explosion.Parent = workspace

			TweenService:Create(explosion, TweenInfo.new(0.3), {
				Size = Vector3.new(8, 8, 8),
				Transparency = 1,
			}):Play()

			damageInRadius(ball.Position, 8, weaponDef.damage, player)
			playSound(142082166, 0.4, 0.8)

			task.delay(0.3, function()
				explosion:Destroy()
			end)
			ball:Destroy()
		end)

		task.delay(3, function()
			if ball.Parent then
				ball:Destroy()
			end
		end)
	elseif weaponDef.projectileType == "beam" then
		-- Beam/ray effect
		local beam = Instance.new("Part")
		beam.Size = Vector3.new(0.4, 0.4, distance)
		beam.Color = weaponDef.color
		beam.Material = Enum.Material.Neon
		beam.Anchored = true
		beam.CanCollide = false
		beam.CFrame = CFrame.lookAt(startPos, targetPos) * CFrame.new(0, 0, -distance / 2)
		beam.Parent = workspace

		-- Damage along beam
		local steps = math.ceil(distance / 4)
		for i = 0, steps do
			local checkPos = startPos + direction * (i * 4)
			damageInRadius(checkPos, 3, weaponDef.damage / steps, player)
		end

		-- Fade out
		TweenService:Create(beam, TweenInfo.new(0.2), {
			Transparency = 1,
			Size = Vector3.new(0.1, 0.1, distance),
		}):Play()

		task.delay(0.2, function()
			beam:Destroy()
		end)
	elseif weaponDef.projectileType == "shards" then
		-- Multiple small projectiles
		for i = 1, 5 do
			local spread = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.3
			local shardDir = (direction + spread).Unit

			local shard = Instance.new("Part")
			shard.Size = Vector3.new(0.3, 0.3, 1.2)
			shard.Color = weaponDef.color
			shard.Material = Enum.Material.SmoothPlastic
			shard.Anchored = false
			shard.CanCollide = false
			shard.CFrame = CFrame.lookAt(startPos, startPos + shardDir)
			shard.Parent = workspace

			local velocity = Instance.new("BodyVelocity")
			velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
			velocity.Velocity = shardDir * 100
			velocity.Parent = shard

			shard.Touched:Connect(function(hit)
				if hit:IsDescendantOf(player.Character) then
					return
				end
				damageInRadius(shard.Position, 3, weaponDef.damage / 5, player)
				shard:Destroy()
			end)

			task.delay(2, function()
				if shard.Parent then
					shard:Destroy()
				end
			end)
		end
	elseif weaponDef.projectileType == "spray" then
		-- Particle spray effect
		local emitter = Instance.new("Part")
		emitter.Size = Vector3.new(1, 1, 1)
		emitter.Transparency = 1
		emitter.Anchored = true
		emitter.CanCollide = false
		emitter.Position = startPos
		emitter.Parent = workspace

		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(weaponDef.color)
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		particles.Lifetime = NumberRange.new(0.5, 0.8)
		particles.Rate = 0
		particles.Speed = NumberRange.new(60, 80)
		particles.SpreadAngle = Vector2.new(15, 15)
		particles.Parent = emitter

		emitter.CFrame = CFrame.lookAt(startPos, targetPos)
		particles:Emit(30)

		-- Damage in cone
		for i = 1, 5 do
			local checkPos = startPos + direction * (i * 8)
			damageInRadius(checkPos, 4, weaponDef.damage / 5, player)
		end

		task.delay(1, function()
			emitter:Destroy()
		end)
	elseif weaponDef.projectileType == "stream" then
		-- Continuous stream
		for i = 1, 8 do
			task.delay(i * 0.05, function()
				local drop = Instance.new("Part")
				drop.Shape = Enum.PartType.Ball
				drop.Size = Vector3.new(0.8, 0.8, 0.8)
				drop.Color = weaponDef.color
				drop.Material = Enum.Material.Neon
				drop.Transparency = 0.3
				drop.Anchored = false
				drop.CanCollide = false
				drop.Position = startPos + direction * (i * 2)
				drop.Parent = workspace

				local velocity = Instance.new("BodyVelocity")
				velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
				velocity.Velocity = direction * 80
				velocity.Parent = drop

				drop.Touched:Connect(function(hit)
					if hit:IsDescendantOf(player.Character) then
						return
					end
					damageInRadius(drop.Position, 3, weaponDef.damage / 8, player)
					drop:Destroy()
				end)

				task.delay(1.5, function()
					if drop.Parent then
						drop:Destroy()
					end
				end)
			end)
		end
	elseif weaponDef.projectileType == "wave" then
		-- Expanding wave effect
		local wave = Instance.new("Part")
		wave.Shape = Enum.PartType.Cylinder
		wave.Size = Vector3.new(0.5, 4, 4)
		wave.Color = weaponDef.color
		wave.Material = Enum.Material.Neon
		wave.Transparency = 0.5
		wave.Anchored = true
		wave.CanCollide = false
		wave.CFrame = CFrame.new(startPos) * CFrame.Angles(0, 0, math.rad(90))
		wave.Parent = workspace

		-- Expand and move forward
		local endPos = startPos + direction * 40
		TweenService:Create(wave, TweenInfo.new(0.5), {
			Size = Vector3.new(0.5, 20, 20),
			CFrame = CFrame.new(endPos) * CFrame.Angles(0, 0, math.rad(90)),
			Transparency = 1,
		}):Play()

		-- Damage along path
		task.spawn(function()
			for i = 1, 10 do
				task.wait(0.05)
				local checkPos = startPos + direction * (i * 4)
				damageInRadius(checkPos, 6, weaponDef.damage / 10, player)
			end
		end)

		task.delay(0.5, function()
			wave:Destroy()
		end)
	elseif weaponDef.projectileType == "spike" then
		-- Ice spike that shoots forward
		local spike = Instance.new("Part")
		spike.Size = Vector3.new(0.6, 0.6, 4)
		spike.Color = weaponDef.color
		spike.Material = Enum.Material.Ice
		spike.Anchored = false
		spike.CanCollide = false
		spike.CFrame = CFrame.lookAt(startPos, targetPos)
		spike.Parent = workspace

		local velocity = Instance.new("BodyVelocity")
		velocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		velocity.Velocity = direction * 90
		velocity.Parent = spike

		spike.Touched:Connect(function(hit)
			if hit:IsDescendantOf(player.Character) then
				return
			end

			-- Freeze effect
			local freeze = Instance.new("Part")
			freeze.Shape = Enum.PartType.Ball
			freeze.Size = Vector3.new(1, 1, 1)
			freeze.Color = weaponDef.color
			freeze.Material = Enum.Material.Ice
			freeze.Transparency = 0.5
			freeze.Anchored = true
			freeze.CanCollide = false
			freeze.Position = spike.Position
			freeze.Parent = workspace

			TweenService:Create(freeze, TweenInfo.new(0.4), {
				Size = Vector3.new(6, 6, 6),
				Transparency = 1,
			}):Play()

			damageInRadius(spike.Position, 5, weaponDef.damage, player)

			task.delay(0.4, function()
				freeze:Destroy()
			end)
			spike:Destroy()
		end)

		task.delay(2.5, function()
			if spike.Parent then
				spike:Destroy()
			end
		end)
	end
end

-- Update weapon appearance based on terrain
local function updateWeaponAppearance()
	if not terrainTool then
		return
	end

	local weaponDef = TERRAIN_WEAPONS[currentWeaponMaterial] or TERRAIN_WEAPONS[Enum.Material.Grass]
	local handle = terrainTool:FindFirstChild("Handle")
	local orb = terrainTool:FindFirstChild("Orb")

	if handle then
		handle.Color = weaponDef.color
	end
	if orb then
		orb.Color = weaponDef.color
	end

	terrainTool.Name = weaponDef.name
end

-- Give player terrain weapon
local function giveWeapon()
	local char = getCharacter()

	-- Remove old weapon if exists
	local existing = player.Backpack:FindFirstChild("TerrainWeapon") or (char and char:FindFirstChild("TerrainWeapon"))
	if existing then
		existing:Destroy()
	end

	local tool = Instance.new("Tool")
	tool.Name = "Thorn Whip"
	tool.Grip = CFrame.new(0, 0, -1)
	tool.Parent = player.Backpack
	terrainTool = tool

	-- Staff handle
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 4)
	handle.Color = Color3.fromRGB(80, 60, 40)
	handle.Material = Enum.Material.Wood
	handle.Parent = tool

	-- Glowing orb at top
	local orb = Instance.new("Part")
	orb.Name = "Orb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(0.8, 0.8, 0.8)
	orb.Color = Color3.fromRGB(200, 220, 255)
	orb.Material = Enum.Material.Neon
	orb.CanCollide = false
	orb.Parent = tool

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = orb
	weld.Parent = orb
	orb.CFrame = handle.CFrame * CFrame.new(0, 0, -2.2)

	-- Attack on activation
	tool.Activated:Connect(function()
		local weaponDef = TERRAIN_WEAPONS[currentWeaponMaterial] or TERRAIN_WEAPONS[Enum.Material.Grass]
		local rootPart = getRootPart()
		if not rootPart then
			return
		end

		local startPos = rootPart.Position + Vector3.new(0, 1, 0) + rootPart.CFrame.LookVector * 2
		local targetPos = mouse.Hit.Position

		playSound(weaponDef.sound, 0.5, 1)
		createProjectile(startPos, targetPos, weaponDef)
	end)

	updateWeaponAppearance()
end

-- Fly
local flyConnection = nil
local function toggleFly()
	powers.fly = not powers.fly
	local humanoid = getHumanoid()
	local rootPart = getRootPart()

	if not humanoid or not rootPart then
		return powers.fly
	end

	if powers.fly then
		flyBodyVelocity = Instance.new("BodyVelocity")
		flyBodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
		flyBodyVelocity.Parent = rootPart

		flyBodyGyro = Instance.new("BodyGyro")
		flyBodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		flyBodyGyro.P = 10000
		flyBodyGyro.D = 500
		flyBodyGyro.Parent = rootPart

		humanoid.PlatformStand = true

		flyConnection = RunService.RenderStepped:Connect(function()
			if not powers.fly or not flyBodyVelocity or not flyBodyGyro then
				return
			end

			local camera = workspace.CurrentCamera
			local moveDirection = Vector3.new(0, 0, 0)

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				moveDirection = moveDirection + camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				moveDirection = moveDirection - camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				moveDirection = moveDirection - camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				moveDirection = moveDirection + camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
				moveDirection = moveDirection + Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
				moveDirection = moveDirection - Vector3.new(0, 1, 0)
			end

			if moveDirection.Magnitude > 0 then
				moveDirection = moveDirection.Unit * FLY_SPEED
			end

			flyBodyVelocity.Velocity = moveDirection
			flyBodyGyro.CFrame = camera.CFrame
		end)
	else
		if flyConnection then
			flyConnection:Disconnect()
			flyConnection = nil
		end
		if flyBodyVelocity then
			flyBodyVelocity:Destroy()
			flyBodyVelocity = nil
		end
		if flyBodyGyro then
			flyBodyGyro:Destroy()
			flyBodyGyro = nil
		end
		humanoid.PlatformStand = false
	end

	return powers.fly
end

-- Hyperspeed
local function toggleHyperspeed()
	powers.hyperspeed = not powers.hyperspeed
	local humanoid = getHumanoid()

	if not humanoid then
		return powers.hyperspeed
	end

	if powers.hyperspeed then
		originalWalkSpeed = humanoid.WalkSpeed
		humanoid.WalkSpeed = originalWalkSpeed * HYPERSPEED_MULTIPLIER
	else
		humanoid.WalkSpeed = originalWalkSpeed
	end

	return powers.hyperspeed
end

-- Super Jump
local function toggleSuperJump()
	powers.superJump = not powers.superJump
	local humanoid = getHumanoid()

	if not humanoid then
		return powers.superJump
	end

	if powers.superJump then
		originalJumpPower = humanoid.JumpPower
		humanoid.JumpPower = SUPER_JUMP_POWER
		humanoid.UseJumpPower = true
	else
		humanoid.JumpPower = originalJumpPower
	end

	return powers.superJump
end

-- Teleport with 3-second hold
local teleportHolding = false
local teleportStartTime = 0
local teleportTarget = nil
local countdownConnection = nil

local function startTeleportCountdown(countdownFrame, countdownLabel)
	teleportHolding = true
	teleportStartTime = tick()
	teleportTarget = mouse.Hit
	countdownFrame.Visible = true

	-- Flash the countdown frame to indicate start
	countdownFrame.BackgroundTransparency = 0.3
	task.delay(0.1, function()
		countdownFrame.BackgroundTransparency = 0.5
	end)

	countdownConnection = RunService.Heartbeat:Connect(function()
		if not teleportHolding then
			countdownFrame.Visible = false
			if countdownConnection then
				countdownConnection:Disconnect()
				countdownConnection = nil
			end
			return
		end

		local elapsed = tick() - teleportStartTime
		local remaining = math.ceil(TELEPORT_HOLD_TIME - elapsed)

		countdownLabel.Text = tostring(math.max(0, remaining))

		-- Progress ring effect with pulsing
		local progress = elapsed / TELEPORT_HOLD_TIME
		countdownFrame.Rotation = progress * 360

		-- Pulsing flash effect instead of sound
		local pulse = math.sin(elapsed * 10) * 0.1
		countdownFrame.BackgroundTransparency = 0.4 + pulse

		if elapsed >= TELEPORT_HOLD_TIME then
			-- Teleport!
			teleportHolding = false
			countdownFrame.Visible = false
			countdownConnection:Disconnect()
			countdownConnection = nil

			local rootPart = getRootPart()
			if rootPart and teleportTarget then
				-- Big flash effect (no sound)
				local flash = Instance.new("Part")
				flash.Size = Vector3.new(4, 4, 4)
				flash.Shape = Enum.PartType.Ball
				flash.Material = Enum.Material.Neon
				flash.Color = Color3.fromRGB(180, 100, 255)
				flash.Anchored = true
				flash.CanCollide = false
				flash.Position = rootPart.Position
				flash.Parent = workspace

				TweenService:Create(flash, TweenInfo.new(0.3), {
					Size = Vector3.new(10, 10, 10),
					Transparency = 1,
				}):Play()
				task.delay(0.3, function()
					flash:Destroy()
				end)

				-- Teleport
				rootPart.CFrame = CFrame.new(teleportTarget.Position + Vector3.new(0, 3, 0))

				-- Arrival effect
				local arrive = flash:Clone()
				arrive.Position = rootPart.Position
				arrive.Size = Vector3.new(10, 10, 10)
				arrive.Transparency = 0.5
				arrive.Parent = workspace

				TweenService:Create(arrive, TweenInfo.new(0.3), {
					Size = Vector3.new(2, 2, 2),
					Transparency = 1,
				}):Play()
				task.delay(0.3, function()
					arrive:Destroy()
				end)
			end
		end
	end)
end

local function cancelTeleport()
	teleportHolding = false
end

-- Dig terrain
local digConnection = nil
local terrain = workspace:FindFirstChildOfClass("Terrain")

local function toggleDig()
	powers.dig = not powers.dig

	if powers.dig then
		digConnection = mouse.Button1Down:Connect(function()
			if not powers.dig or not terrain then
				return
			end

			local hit = mouse.Hit
			if hit then
				local pos = hit.Position

				-- Dig a sphere out of terrain
				local region = Region3.new(
					pos - Vector3.new(DIG_RADIUS, DIG_RADIUS, DIG_RADIUS),
					pos + Vector3.new(DIG_RADIUS, DIG_RADIUS, DIG_RADIUS)
				)

				terrain:FillBall(pos, DIG_RADIUS, Enum.Material.Air)

				-- Dig sound
				playSound(1369158539, 0.5, 0.8)

				-- Dust effect
				local dust = Instance.new("Part")
				dust.Size = Vector3.new(1, 1, 1)
				dust.Transparency = 1
				dust.Anchored = true
				dust.CanCollide = false
				dust.Position = pos
				dust.Parent = workspace

				local particles = Instance.new("ParticleEmitter")
				particles.Color = ColorSequence.new(Color3.fromRGB(139, 105, 73))
				particles.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 2),
					NumberSequenceKeypoint.new(1, 0),
				})
				particles.Lifetime = NumberRange.new(0.5, 1)
				particles.Rate = 0
				particles.Speed = NumberRange.new(10, 20)
				particles.SpreadAngle = Vector2.new(180, 180)
				particles.Parent = dust

				particles:Emit(30)
				task.delay(1.5, function()
					dust:Destroy()
				end)
			end
		end)
	else
		if digConnection then
			digConnection:Disconnect()
			digConnection = nil
		end
	end

	return powers.dig
end

-- Reset powers on respawn
local function onCharacterAdded(character)
	powers.fly = false
	powers.hyperspeed = false
	powers.superJump = false

	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end
	flyBodyVelocity = nil
	flyBodyGyro = nil

	-- Give weapon on spawn
	task.delay(0.5, giveWeapon)
end

player.CharacterAdded:Connect(onCharacterAdded)

-- Initialize UI
local screenGui, buttonList, swatch, materialLabel, countdownFrame, countdownLabel = createUI()

-- Terrain detection
local lastMaterial = nil

local function updateTerrainDetector()
	local rootPart = getRootPart()
	if not rootPart or not terrain then
		return
	end

	local rayOrigin = rootPart.Position
	local rayDirection = Vector3.new(0, -10, 0)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { terrain }

	local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)

	local detectedMaterial = Enum.Material.Air

	if result and result.Instance == terrain then
		detectedMaterial = result.Material
	end

	if detectedMaterial ~= lastMaterial then
		lastMaterial = detectedMaterial

		local info = MATERIAL_COLORS[detectedMaterial]
		if info then
			materialLabel.Text = info.name
			TweenService:Create(swatch, TweenInfo.new(0.2), {
				BackgroundColor3 = info.color,
			}):Play()
		else
			materialLabel.Text = tostring(detectedMaterial.Name)
			swatch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		end

		-- Only update weapon for non-Air terrain (keep last solid terrain weapon)
		if detectedMaterial ~= Enum.Material.Air then
			currentWeaponMaterial = detectedMaterial
			updateWeaponAppearance()
		end
	end
end

RunService.Heartbeat:Connect(updateTerrainDetector)

-- Create buttons
local buttonRefs = {}

local powerActions = {
	fly = toggleFly,
	hyperspeed = toggleHyperspeed,
	superJump = toggleSuperJump,
	teleport = function()
		return powers.teleport
	end, -- Handled separately
	dig = toggleDig,
}

-- Function to update button visual state
local function updateButtonVisual(refs, isActive)
	local button, bar, dot, color, label, hotkeyLabel = refs.button, refs.bar, refs.dot, refs.color, refs.label, refs.hotkeyLabel

	-- Animate bar (thicker and brighter when on)
	TweenService:Create(bar, TweenInfo.new(0.15), {
		BackgroundTransparency = isActive and 0 or 0.5,
		Size = isActive and UDim2.new(0, 6, 1, -8) or UDim2.new(0, 4, 1, -8),
	}):Play()

	-- Animate dot (glowing when on)
	TweenService:Create(dot, TweenInfo.new(0.15), {
		BackgroundColor3 = isActive and color or Color3.fromRGB(50, 55, 65),
		Size = isActive and UDim2.new(0, 14, 0, 14) or UDim2.new(0, 12, 0, 12),
		Position = isActive and UDim2.new(1, -21, 0.5, -7) or UDim2.new(1, -20, 0.5, -6),
	}):Play()

	-- Animate label (brighter when on)
	TweenService:Create(label, TweenInfo.new(0.15), {
		TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200),
		TextSize = isActive and 20 or 18,
	}):Play()

	-- Animate hotkey (highlighted when on)
	TweenService:Create(hotkeyLabel, TweenInfo.new(0.15), {
		BackgroundColor3 = isActive and color or Color3.fromRGB(50, 55, 65),
		TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 180, 180),
		BackgroundTransparency = isActive and 0 or 0.5,
	}):Play()

	-- Animate button background
	TweenService:Create(button, TweenInfo.new(0.15), {
		BackgroundColor3 = isActive and Color3.fromRGB(40, 50, 60) or Color3.fromRGB(30, 34, 40),
	}):Play()
end

for i, config in ipairs(BUTTON_CONFIGS) do
	local button, bar, dot, color, label, hotkeyLabel = createPowerButton(buttonList, config, i)
	buttonRefs[config.key] = {
		button = button,
		bar = bar,
		dot = dot,
		color = color,
		label = label,
		hotkeyLabel = hotkeyLabel,
		config = config,
	}

	if config.key == "teleport" then
		-- Teleport needs special handling - hold to activate
		button.MouseButton1Down:Connect(function()
			if powers.teleport then
				startTeleportCountdown(countdownFrame, countdownLabel)
			end
		end)

		button.MouseButton1Up:Connect(function()
			cancelTeleport()
		end)

		-- Toggle teleport mode
		button.MouseButton1Click:Connect(function()
			powers.teleport = not powers.teleport
			updateButtonVisual(buttonRefs[config.key], powers.teleport)
		end)
	else
		button.MouseButton1Click:Connect(function()
			local isActive = powerActions[config.key]()
			updateButtonVisual(buttonRefs[config.key], isActive)
		end)
	end

	-- Hover (only if not active)
	button.MouseEnter:Connect(function()
		if not powers[config.key] then
			TweenService:Create(button, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(40, 45, 55),
			}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		if not powers[config.key] then
			TweenService:Create(button, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(30, 34, 40),
			}):Play()
		end
		cancelTeleport() -- Cancel if mouse leaves button
	end)
end

-- Keyboard shortcuts (F=Fly, S=Speed, J=Jump, W=Warp, D=Dig)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	for _, config in ipairs(BUTTON_CONFIGS) do
		if input.KeyCode == config.hotkey then
			local refs = buttonRefs[config.key]

			if config.key == "teleport" then
				-- Toggle teleport mode
				powers.teleport = not powers.teleport
				updateButtonVisual(refs, powers.teleport)
			else
				local isActive = powerActions[config.key]()
				updateButtonVisual(refs, isActive)
			end
			break
		end
	end
end)

-- Middle-click for teleport when enabled
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		if powers.teleport then
			startTeleportCountdown(countdownFrame, countdownLabel)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		cancelTeleport()
	end
end)

-- Q key to turn off all powers
local function turnOffAllPowers()
	-- Turn off fly
	if powers.fly then
		toggleFly()
		updateButtonVisual(buttonRefs.fly, false)
	end

	-- Turn off speed
	if powers.hyperspeed then
		toggleHyperspeed()
		updateButtonVisual(buttonRefs.hyperspeed, false)
	end

	-- Turn off jump
	if powers.superJump then
		toggleSuperJump()
		updateButtonVisual(buttonRefs.superJump, false)
	end

	-- Turn off teleport
	powers.teleport = false
	cancelTeleport()
	updateButtonVisual(buttonRefs.teleport, false)

	-- Turn off dig
	if powers.dig then
		toggleDig()
		updateButtonVisual(buttonRefs.dig, false)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	-- Q turns off all powers only when NOT flying (since Q is used for descend while flying)
	if input.KeyCode == Enum.KeyCode.Q and not powers.fly then
		turnOffAllPowers()
	end

	-- X always turns off all powers
	if input.KeyCode == Enum.KeyCode.X then
		turnOffAllPowers()
	end
end)

-- Give weapon on load
task.delay(1, giveWeapon)

print("TerrainPowers loaded! F=Fly S=Speed J=Jump W=Warp D=Dig. Q=all off. Hold 1s to warp.")
