---@diagnostic disable: lowercase-global

local love = require("love")

local Vector3 = require("vector3")
local RigidBody = require("rigidbody")
local Camera = require("camera")

local objects = {}
local gravity = Vector3.new(0, -9.81, 0)
local worldBounds = {
    min = Vector3.new(-100, 0.0, -100),
    max = Vector3.new(100, 50, 100)
}
local cam

local kickStrength = 30
local maxKickDistance = 15

function raySphereIntersect(rayOrigin, rayDir, spherePos, sphereRadius)
    local C_Svector = spherePos:sub(rayOrigin)
    local C_SvectorProjection = C_Svector:dot(rayDir)
    local S_Rdistance = C_Svector:lengthSq() - C_SvectorProjection * C_SvectorProjection
    local radiusSq = sphereRadius * sphereRadius
    if S_Rdistance > radiusSq then return nil end
    local halfChordLength = math.sqrt(radiusSq - S_Rdistance)
    local t0 = C_SvectorProjection - halfChordLength
    local t1 = C_SvectorProjection + halfChordLength
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
end

function love.mousepressed(x, y, button, istouch, presses)
    if button == 1 then
        performKick()
    end
end

function performKick()
    local closestObject = nil
    local closestDist = maxKickDistance + 1

    local rayOrigin = cam.position:clone()
    local rayDir = cam.forward:normalize()

    for i, obj in ipairs(objects) do
        local t = raySphereIntersect(rayOrigin, rayDir, obj.position, obj.radius)

        if t and t > 0 and t < closestDist then
            if t <= maxKickDistance then
                closestDist = t
                closestObject = obj
            end
        end
    end

    if closestObject then
        local kickDirection = cam.forward:normalize()

        local velocityBoost = kickDirection:mul(kickStrength)

        closestObject.velocity = closestObject.velocity:add(velocityBoost)
    end
end

function love.load()
    love.window.setTitle("Basic 3D Physics in LÖVE")
    math.randomseed(os.time())

    cam = Camera.new(
        Vector3.new(10, 20, -15),
        Vector3.new(0, 20, 0),
        Vector3.new(0, 1, 0),
        math.rad(60),
        love.graphics.getWidth() / love.graphics.getHeight(), 
        0.1,
        100)

    for i = 1, 15 do
        table.insert(objects, RigidBody.new(
            math.random(-5, 5),
            math.random(5, 50),
            math.random(-5, 5),
            math.random() * 0.5 + 0.5,
            math.random() * 2 + 0.5
        ))
    end
    objects[1].color = { 1, 0, 0, 1 }

    love.mouse.setRelativeMode(true)
end

function love.update(dt)
    for i, obj in ipairs(objects) do
        obj:applyForce(gravity:mul(obj.mass))
        obj:update(dt)
    end

    for i = 1, #objects do
        for j = i + 1, #objects do
            local objA = objects[i]
            local objB = objects[j]
            checkAndResolveSphereCollision(objA, objB)
        end
    end

    for i, obj in ipairs(objects) do
        checkAndResolveBoundaryCollision(obj, worldBounds)
    end

    local moveSpeed = 10 * dt
    if love.keyboard.isDown("w") then cam.position = cam.position:add(cam.forward:mul(moveSpeed)) end
    if love.keyboard.isDown("s") then cam.position = cam.position:sub(cam.forward:mul(moveSpeed)) end
    if love.keyboard.isDown("a") then cam.position = cam.position:sub(cam.right:mul(moveSpeed)) end
    if love.keyboard.isDown("d") then cam.position = cam.position:add(cam.right:mul(moveSpeed)) end
    if love.keyboard.isDown("space") then cam.position = cam.position:add(cam.worldUp:mul(moveSpeed)) end
    if love.keyboard.isDown("lshift") then cam.position = cam.position:sub(cam.worldUp:mul(moveSpeed)) end

    cam.lookAtPoint = cam.position:add(cam.forward)
end

function love.mousemoved(x, y, dx, dy)
    cam:mouseLook(dx, dy)
end

function checkAndResolveSphereCollision(objA, objB)
    local diff = objA.position:sub(objB.position)
    local distSq = diff:lengthSq()
    local totalRadius = objA.radius + objB.radius

    if distSq < totalRadius * totalRadius and distSq > 0.0001 then
        local dist = math.sqrt(distSq)
        local normal = diff:div(dist)
        local penetration = totalRadius - dist

        local totalInvMass = objA.invMass + objB.invMass
        if totalInvMass == 0 then totalInvMass = 1 end

        local correctionA = normal:mul(penetration * (objA.invMass / totalInvMass))
        local correctionB = normal:mul(-penetration * (objB.invMass / totalInvMass))
        objA.position = objA.position:add(correctionA)
        objB.position = objB.position:add(correctionB)

        local relativeVelocity = objA.velocity:sub(objB.velocity)
        local velocityAlongNormal = relativeVelocity:dot(normal)

        if velocityAlongNormal < 0 then
            local restitution = math.min(objA.bounciness, objB.bounciness)
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

    if obj.position.x - obj.radius < bounds.min.x then
        penetration = bounds.min.x - (obj.position.x - obj.radius)
        obj.position.x = obj.position.x + penetration
        obj.velocity.x = -obj.velocity.x * obj.bounciness
    elseif obj.position.x + obj.radius > bounds.max.x then
        penetration = (obj.position.x + obj.radius) - bounds.max.x
        obj.position.x = obj.position.x - penetration
        obj.velocity.x = -obj.velocity.x * obj.bounciness
    end

    if obj.position.y - obj.radius < bounds.min.y then
        penetration = bounds.min.y - (obj.position.y - obj.radius)
        obj.position.y = obj.position.y + penetration
        obj.velocity.y = -obj.velocity.y * obj.bounciness
    elseif obj.position.y + obj.radius > bounds.max.y then
        penetration = (obj.position.y + obj.radius) - bounds.max.y
        obj.position.y = obj.position.y - penetration
        obj.velocity.y = -obj.velocity.y * obj.bounciness
    end

    if obj.position.z - obj.radius < bounds.min.z then
        penetration = bounds.min.z - (obj.position.z - obj.radius)
        obj.position.z = obj.position.z + penetration
        obj.velocity.z = -obj.velocity.z * obj.bounciness
    elseif obj.position.z + obj.radius > bounds.max.z then
        penetration = (obj.position.z + obj.radius) - bounds.max.z
        obj.position.z = obj.position.z - penetration
        obj.velocity.z = -obj.velocity.z * obj.bounciness
    end
end

function love.draw()
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    local gridSize = 2
    local numCellsX = 60
    local numCellsZ = 60
    local gridYLevel = 0.0

    local screenWidth, screenHeight = love.graphics.getWidth(), love.graphics.getHeight()

    local projectedPoints = {}

    for iz = -numCellsZ, numCellsZ do
        projectedPoints[iz] = {}
        for ix = -numCellsX, numCellsX do
            local worldX = ix * gridSize
            local worldZ = iz * gridSize
            local p_world = Vector3.new(worldX, gridYLevel, worldZ)
            local sx, sy, s_depth = cam:project(p_world)
            if sx then
                projectedPoints[iz][ix] = { x = sx, y = sy, depth = s_depth, valid = true }
            else
                projectedPoints[iz][ix] = { valid = false }
            end
        end
    end

    for ix = -numCellsX, numCellsX do
        for iz = -numCellsZ, numCellsZ - 1 do
            local p1_info = projectedPoints[iz][ix]
            local p2_info = projectedPoints[iz + 1][ix]

            if p1_info.valid and p2_info.valid then
                local bothVisibleIsh = true

                if bothVisibleIsh then
                    love.graphics.line(p1_info.x, p1_info.y, p2_info.x, p2_info.y)
                end
            end
        end
    end

    for iz = -numCellsZ, numCellsZ do
        for ix = -numCellsX, numCellsX - 1 do
            local p1_info = projectedPoints[iz][ix]
            local p2_info = projectedPoints[iz][ix + 1]

            if p1_info.valid and p2_info.valid then
                local bothVisibleIsh = true

                if bothVisibleIsh then
                    love.graphics.line(p1_info.x, p1_info.y, p2_info.x, p2_info.y)
                end
            end
        end
    end

    love.graphics.print("3D Physics Demo. WASD+Mouse to move. M to toggle mouse. ESC to quit.", 10, 10)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 30)
    love.graphics.print("Objects: " .. #objects, 10, 50)

    local sortedObjects = {}
    for i, obj in ipairs(objects) do
        table.insert(sortedObjects, obj)
    end
    table.sort(sortedObjects, function(a, b)
        local distA = (a.position:sub(cam.position)):lengthSq()
        local distB = (b.position:sub(cam.position)):lengthSq()
        return distA > distB
    end)

    for _, obj in ipairs(sortedObjects) do
        local x, y, z_depth = cam:project(obj.position)

        if x and y then
            local screenRadius = obj.radius * (love.graphics.getHeight() / 2) /
                (math.tan(cam.fov / 2) * math.max(1, z_depth))

            if screenRadius > 0.5 then
                love.graphics.setColor(obj.color)
                love.graphics.circle("fill", x, y, math.max(1, screenRadius))
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.circle("line", x, y, math.max(1, screenRadius))
            end
        end
    end

    love.graphics.setColor(1, 1, 1, 0.5)
    local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    love.graphics.line(cx - 10, cy, cx + 10, cy)
    love.graphics.line(cx, cy - 10, cx, cy + 10)
end