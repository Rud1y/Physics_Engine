---@diagnostic disable: lowercase-global

local love = require("love")

local Vector3 = require("vector3")
local RigidBody = require("rigidbody")
local Camera = require("camera")

local objects = {}
local gravity = Vector3.new(0, -9.81, 0)
local worldBounds = {
    min = Vector3.new(-100, 0.0, -100), -- Ground plane at Y=0
    max = Vector3.new(100, 50, 100)     -- Walls and a ceiling
}
local cam

local kickStrength = 30    -- Adjust as needed (this will be like a speed boost)
local maxKickDistance = 15 -- How far the kick can reach

function raySphereIntersect(rayOrigin, rayDir, spherePos, sphereRadius)
    local L = spherePos:sub(rayOrigin)
    local tca = L:dot(rayDir)
    local d2 = L:lengthSq() - tca * tca
    local radiusSq = sphereRadius * sphereRadius
    if d2 > radiusSq then return nil end
    local thc = math.sqrt(radiusSq - d2)
    local t0 = tca - thc
    local t1 = tca + thc
    if t0 < 0 and t1 < 0 then return nil end
    if t0 < 0 then return t1 end
    return math.min(t0, t1)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
    if key == "m" then
        love.mouse.setRelativeMode(not love.mouse.isRelativeMode())
    end

    if key == "return" then -- "Enter" key
        performKick()
    end
end

function performKick()
    local closestObject = nil
    local closestDist = maxKickDistance + 1 -- Start with a distance greater than max

    local rayOrigin = cam.position:clone()
    local rayDir = cam.forward:normalize() -- Ensure camera forward vector is normalized

    for i, obj in ipairs(objects) do
        local t = raySphereIntersect(rayOrigin, rayDir, obj.position, obj.radius)

        if t and t > 0 and t < closestDist then
            -- Check if intersection point is within maxKickDistance
            if t <= maxKickDistance then
                closestDist = t
                closestObject = obj
            end
        end
    end

    if closestObject then
        -- Apply the kick!
        -- The kick will be in the direction the camera is facing.
        local kickDirection = cam.forward:normalize() -- Already normalized, but good practice

        -- We'll directly add to the object's velocity (acting like an impulse)
        -- The amount of velocity added can be kickStrength, or scaled by inverse mass
        -- For a simple arcade feel, a direct speed boost is fine.
        -- dv = F_impulse / mass. If F_impulse is kickStrength * kickDirection then:
        -- local velocityChange = kickDirection:mul(kickStrength / closestObject.mass) -- More physical
        local velocityBoost = kickDirection:mul(kickStrength) -- Simpler, fixed speed boost

        closestObject.velocity = closestObject.velocity:add(velocityBoost)
    end
end

function love.load()
    love.window.setTitle("Basic 3D Physics in LÖVE")
    math.randomseed(os.time())

    cam = Camera.new(
        Vector3.new(10, 20, -15),                               -- Position
        Vector3.new(0, 20, 0),                                 -- LookAt
        Vector3.new(0, 1, 0),                                 -- Up
        math.rad(60),                                         -- FOV
        love.graphics.getWidth() / love.graphics.getHeight(), -- Aspect
        0.1,                                                  -- Near
        100                                                   -- Far
    )

    for i = 1, 15 do
        table.insert(objects, RigidBody.new(
            math.random(-5, 5),
            math.random(5, 50),
            math.random(-5, 5),
            math.random() * 0.5 + 0.5, -- radius
            math.random() * 2 + 0.5    -- mass
        ))
    end
    objects[1].color = { 1, 0, 0, 1 } -- Make first one red for easier tracking

    love.mouse.setRelativeMode(true)
end

function love.update(dt)
    -- Basic physics update loop
    for i, obj in ipairs(objects) do
        obj:applyForce(gravity:mul(obj.mass)) -- Apply gravity
        obj:update(dt)
    end

    -- Collision detection and response
    for i = 1, #objects do
        for j = i + 1, #objects do
            local objA = objects[i]
            local objB = objects[j]
            checkAndResolveSphereCollision(objA, objB)
        end
    end

    -- Boundary collision
    for i, obj in ipairs(objects) do
        checkAndResolveBoundaryCollision(obj, worldBounds)
    end

    -- Camera movement (very basic WASD + mouse)
    local moveSpeed = 10 * dt
    if love.keyboard.isDown("w") then cam.position = cam.position:add(cam.forward:mul(moveSpeed)) end
    if love.keyboard.isDown("s") then cam.position = cam.position:sub(cam.forward:mul(moveSpeed)) end
    if love.keyboard.isDown("a") then cam.position = cam.position:sub(cam.right:mul(moveSpeed)) end
    if love.keyboard.isDown("d") then cam.position = cam.position:add(cam.right:mul(moveSpeed)) end
    if love.keyboard.isDown("space") then cam.position = cam.position:add(cam.worldUp:mul(moveSpeed)) end
    if love.keyboard.isDown("lshift") then cam.position = cam.position:sub(cam.worldUp:mul(moveSpeed)) end

    -- Update camera's lookAt point based on its forward vector after movement
    cam.lookAtPoint = cam.position:add(cam.forward)
end

function love.mousemoved(x, y, dx, dy)
        cam:mouseLook(dx, dy)
end

function checkAndResolveSphereCollision(objA, objB)
    local diff = objA.position:sub(objB.position)
    local distSq = diff:lengthSq()
    local totalRadius = objA.radius + objB.radius

    if distSq < totalRadius * totalRadius and distSq > 0.0001 then -- Collision
        local dist = math.sqrt(distSq)
        local normal = diff:div(dist)                              -- Normalized collision normal (from B to A)
        local penetration = totalRadius - dist

        -- 1. Positional Correction (to prevent sinking)
        -- Move objects apart along the normal, proportional to their inverse masses
        local totalInvMass = objA.invMass + objB.invMass
        if totalInvMass == 0 then totalInvMass = 1 end -- Both kinematic or infinite mass

        local correctionA = normal:mul(penetration * (objA.invMass / totalInvMass))
        local correctionB = normal:mul(-penetration * (objB.invMass / totalInvMass))
        objA.position = objA.position:add(correctionA)
        objB.position = objB.position:add(correctionB)

        -- 2. Impulse-based Response
        local relativeVelocity = objA.velocity:sub(objB.velocity)
        local velocityAlongNormal = relativeVelocity:dot(normal)

        if velocityAlongNormal < 0 then -- Objects are moving towards each other
            local restitution = math.min(objA.restitution, objB.restitution)
            local impulseScalar = -(1 + restitution) * velocityAlongNormal
            impulseScalar = impulseScalar / totalInvMass

            local impulse = normal:mul(impulseScalar)
            objA.velocity = objA.velocity:add(impulse:mul(objA.invMass))
            objB.velocity = objB.velocity:sub(impulse:mul(objB.invMass))
        end
    end
end

function checkAndResolveBoundaryCollision(obj, bounds)
    local collisionNormal = Vector3.new()
    local penetration = 0

    -- X-axis
    if obj.position.x - obj.radius < bounds.min.x then
        penetration = bounds.min.x - (obj.position.x - obj.radius)
        obj.position.x = obj.position.x + penetration
        obj.velocity.x = -obj.velocity.x * obj.restitution
    elseif obj.position.x + obj.radius > bounds.max.x then
        penetration = (obj.position.x + obj.radius) - bounds.max.x
        obj.position.x = obj.position.x - penetration
        obj.velocity.x = -obj.velocity.x * obj.restitution
    end

    -- Y-axis (Ground and Ceiling)
    if obj.position.y - obj.radius < bounds.min.y then
        penetration = bounds.min.y - (obj.position.y - obj.radius)
        obj.position.y = obj.position.y + penetration
        obj.velocity.y = -obj.velocity.y * obj.restitution
    elseif obj.position.y + obj.radius > bounds.max.y then
        penetration = (obj.position.y + obj.radius) - bounds.max.y
        obj.position.y = obj.position.y - penetration
        obj.velocity.y = -obj.velocity.y * obj.restitution
    end

    -- Z-axis
    if obj.position.z - obj.radius < bounds.min.z then
        penetration = bounds.min.z - (obj.position.z - obj.radius)
        obj.position.z = obj.position.z + penetration
        obj.velocity.z = -obj.velocity.z * obj.restitution
    elseif obj.position.z + obj.radius > bounds.max.z then
        penetration = (obj.position.z + obj.radius) - bounds.max.z
        obj.position.z = obj.position.z - penetration
        obj.velocity.z = -obj.velocity.z * obj.restitution
    end
end

function love.draw()
    -- Draw simple ground grid by projecting points and connecting them
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    local gridSize = 2    -- The size of each grid cell in world units
    local numCellsX = 60   -- Number of cells from center along X (e.g., 20 cells = -10 to +10 cells from origin)
    local numCellsZ = 60   -- Number of cells from center along Z
    local gridYLevel = 0.0 -- Y-coordinate for the grid plane

    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    -- Store projected points: projectedPoints[z_index][x_index] = {x_screen, y_screen, z_depth}
    local projectedPoints = {}

    -- Project all grid intersection points
    for iz = -numCellsZ, numCellsZ do
        projectedPoints[iz] = {}
        for ix = -numCellsX, numCellsX do
            local worldX = ix * gridSize
            local worldZ = iz * gridSize
            local p_world = Vector3.new(worldX, gridYLevel, worldZ)
            local sx, sy, s_depth = cam:project(p_world)
            if sx then -- if successfully projected
                projectedPoints[iz][ix] = { x = sx, y = sy, depth = s_depth, valid = true }
            else
                projectedPoints[iz][ix] = { valid = false }
            end
        end
    end

    -- Draw lines based on projected points
    -- Lines parallel to Z-axis (iterate over X columns)
    for ix = -numCellsX, numCellsX do
        for iz = -numCellsZ, numCellsZ - 1 do -- Go up to one less than max to connect to iz+1
            local p1_info = projectedPoints[iz][ix]
            local p2_info = projectedPoints[iz + 1][ix]

            if p1_info.valid and p2_info.valid then
                -- Optional: Basic screen space culling for lines (prevents drawing huge lines if one point is far off-screen)
                local bothVisibleIsh = true -- Assume visible unless proven otherwise
                -- Add more sophisticated checks here if needed, e.g. checking if both x,y are within screen + margin
                -- For simplicity, we'll draw if both projected.

                if bothVisibleIsh then
                    love.graphics.line(p1_info.x, p1_info.y, p2_info.x, p2_info.y)
                end
            end
        end
    end

    -- Lines parallel to X-axis (iterate over Z rows)
    for iz = -numCellsZ, numCellsZ do
        for ix = -numCellsX, numCellsX - 1 do -- Go up to one less than max to connect to ix+1
            local p1_info = projectedPoints[iz][ix]
            local p2_info = projectedPoints[iz][ix + 1]

            if p1_info.valid and p2_info.valid then
                local bothVisibleIsh = true -- Assume visible
                -- Add screen culling logic as above if desired

                if bothVisibleIsh then
                    love.graphics.line(p1_info.x, p1_info.y, p2_info.x, p2_info.y)
                end
            end
        end
    end

    love.graphics.print("3D Physics Demo. WASD+Mouse to move. M to toggle mouse. ESC to quit.", 10, 10)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 30)
    love.graphics.print("Objects: " .. #objects, 10, 50)

    -- Sort objects by distance from camera (Painter's algorithm, very basic)
    -- Farther objects are drawn first.
    local sortedObjects = {}
    for i, obj in ipairs(objects) do
        table.insert(sortedObjects, obj)
    end
    table.sort(sortedObjects, function(a, b)
        local distA = (a.position:sub(cam.position)):lengthSq()
        local distB = (b.position:sub(cam.position)):lengthSq()
        return distA > distB -- Sort descending by distance (farther first)
    end)

    for _, obj in ipairs(sortedObjects) do
        local x, y, z_depth = cam:project(obj.position)

        if x and y then -- If it's projectable (not culled)
            -- Scale radius based on distance for pseudo-3D effect
            -- This is a hack; proper perspective projection does this via the math.
            -- The projection math should already scale it correctly if drawing a true 3D sphere.
            -- Here we are drawing a 2D circle, so we estimate its apparent size.
            local screenRadius = obj.radius * (love.graphics.getHeight() / 2) /
                (math.tan(cam.fov / 2) * math.max(1, z_depth))

            if screenRadius > 0.5 then -- Don't draw tiny specks
                love.graphics.setColor(obj.color)
                love.graphics.circle("fill", x, y, math.max(1, screenRadius))
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.circle("line", x, y, math.max(1, screenRadius))
            end
        end
    end

    -- Crosshair
    love.graphics.setColor(1, 1, 1, 0.5)
    local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    love.graphics.line(cx - 10, cy, cx + 10, cy)
    love.graphics.line(cx, cy - 10, cx, cy + 10)
end