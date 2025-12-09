-- Player tweaks - LocalScript
-- WalkSpeed 68, MaxZoomDistance 10000

local Players = game:GetService("Players")

local WALK_SPEED = 68
local MAX_ZOOM_DISTANCE = 10000

local player = Players.LocalPlayer

-- Camera zoom
player.CameraMaxZoomDistance = MAX_ZOOM_DISTANCE

-- Walk speed
local function setWalkSpeed(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid.WalkSpeed = WALK_SPEED
end

if player.Character then
	setWalkSpeed(player.Character)
end

player.CharacterAdded:Connect(setWalkSpeed)

