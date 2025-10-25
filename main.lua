---@diagnostic disable: lowercase-global

--[[RESTRUCTURE:
new utility file for:
-collision detection
-collision resolution
-inercia tensor calculation
-broadphase methods, narrowphase methods
]]

local love = require("love")

local Vector3 = require("vector3")
local RigidBody = require("rigidbody")
local Camera = require("camera")
local mat4 = require("mat4")

local objects = {}
local gravity = Vector3.new(0, -9.81, 0)
local worldBounds = {
    min = Vector3.new(-100, 0.0, -100),
    max = Vector3.new(100, 50, 100)
}
local cam

local kickStrength = 5
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

function rayCubeIntersect(rayOrigin, rayDir, cube, faceName)
    local planeNormal
    local pointOnPlane

    local hE = cube.halfExtents
    if faceName == "front" then -- -Z face
        planeNormal = Vector3.new(0, 0, -1)
        pointOnPlane = cube.position:add(Vector3.new(0, 0, -hE.z))
    elseif faceName == "back" then -- +Z face
        planeNormal = Vector3.new(0, 0, 1)
        pointOnPlane = cube.position:add(Vector3.new(0, 0, hE.z))
    elseif faceName == "top" then -- +Y face
        planeNormal = Vector3.new(0, 1, 0)
        pointOnPlane = cube.position:add(Vector3.new(0, hE.y, 0))
    elseif faceName == "bottom" then -- -Y face
        planeNormal = Vector3.new(0, -1, 0)
        pointOnPlane = cube.position:add(Vector3.new(0, -hE.y, 0))
    elseif faceName == "right" then -- +X face
        planeNormal = Vector3.new(1, 0, 0)
        pointOnPlane = cube.position:add(Vector3.new(hE.x, 0, 0))
    elseif faceName == "left" then -- -X face
        planeNormal = Vector3.new(-1, 0, 0)
        pointOnPlane = cube.position:add(Vector3.new(-hE.x, 0, 0))
    else
        return nil
    end

    local denominator = rayDir:dot(planeNormal)

    if math.abs(denominator) < 0.0001 then
        return nil
    end

    local numerator = (pointOnPlane:sub(rayOrigin)):dot(planeNormal)
    local t = numerator / denominator

    if t < 0 then
        return nil
    end

    local intersectionPoint = rayOrigin:add(rayDir:mul(t))

    if faceName == "front" or faceName == "back" then
        if math.abs(intersectionPoint.x - cube.position.x) > hE.x or
            math.abs(intersectionPoint.y - cube.position.y) > hE.y then
            return nil
        end
    elseif faceName == "top" or faceName == "bottom" then
        if math.abs(intersectionPoint.x - cube.position.x) > hE.x or
            math.abs(intersectionPoint.z - cube.position.z) > hE.z then
            return nil
        end
    elseif faceName == "left" or faceName == "right" then
        if math.abs(intersectionPoint.y - cube.position.y) > hE.y or
            math.abs(intersectionPoint.z - cube.position.z) > hE.z then
            return nil
        end
    end

    return t, intersectionPoint
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
    local closestHitPoint = nil

    local rayOrigin = cam.position:clone()
    local rayDir = cam.forward:normalize()

    for i, obj in ipairs(objects) do
        if obj.type == "sphere" then
            local t = raySphereIntersect(rayOrigin, rayDir, obj.position, obj.radius)
            if t and t > 0 and t < closestDist and t <= maxKickDistance then
                closestDist = t
                closestObject = obj
                closestHitPoint = rayOrigin:add(rayDir:mul(t))
            end
        elseif obj.type == "cube" then
            local faces = { "front", "back", "top", "bottom", "left", "right" }
            for _, faceName in ipairs(faces) do
                local t, hitPoint = rayCubeIntersect(rayOrigin, rayDir, obj, faceName)
                if t and t > 0 and t < closestDist and t <= maxKickDistance then
                    closestDist = t
                    closestObject = obj
                    closestHitPoint = hitPoint
                end
            end
        end
    end

    if closestObject and closestHitPoint then
        local impulseDirection = cam.forward:normalize()
        local impulseMagnitude = kickStrength * 20
        local impulseVector = impulseDirection:mul(impulseMagnitude)

        local linearVelocityChange = impulseVector:mul(closestObject.invMass)
        closestObject.velocity = closestObject.velocity:add(linearVelocityChange)

        local r = closestHitPoint:sub(closestObject.position)

        local angularImpulse = r:cross(impulseVector)

        local simplifiedInvInertia = 1.0
        local angularVelocityChange = angularImpulse:mul(simplifiedInvInertia * closestObject.invMass)

        closestObject.angularVelocity = closestObject.angularVelocity:add(angularVelocityChange)
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
        table.insert(objects, RigidBody.new({
            type = "sphere",
            position = Vector3.new(math.random(-5, 5), math.random(5, 50), math.random(-5, 5)),
            radius = math.random() * 0.5 + 0.5,
            mass = math.random() * 2 + 0.5,
            bounciness = 0.7
        }))
    end

    table.insert(objects, RigidBody.new({
        type = "cube",
        position = Vector3.new(5, 20, 5),
        halfExtents = Vector3.new(2, 2, 2),
        mass = 10,
        bounciness = 0.5,
        color = { 0.8, 0.2, 0.2, 1 }
    }))
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

            local typeA = objA.type
            local typeB = objB.type

            if typeA == "sphere" and typeB == "sphere" then
                checkAndResolveSphereCollision(objA, objB)
            elseif typeA == "sphere" and typeB == "cube" then
                if checkSphereCubeCollision(objA, objB) then
                    love.graphics.print("COLLISION: Sphere and Cube are touching!", 10, 70)
                end
            elseif typeA == "cube" and typeB == "sphere" then
                if checkSphereCubeCollision(objB, objA) then
                    love.graphics.print("COLLISION: Cube and Sphere are touching!", 10, 70)
                end
            elseif typeA == "cube" and typeB == "cube" then
                checkAndResolveCubeCubeCollision(objA, objB)
            end
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

function checkSphereCubeCollision(sphere, cube)
    local closestPoint = Vector3.new(
        math.max(cube.position.x - cube.halfExtents.x, math.min(sphere.position.x, cube.position.x + cube.halfExtents.x)),
        math.max(cube.position.y - cube.halfExtents.y, math.min(sphere.position.y, cube.position.y + cube.halfExtents.y)),
        math.max(cube.position.z - cube.halfExtents.z, math.min(sphere.position.z, cube.position.z + cube.halfExtents.z))
    )

    local diff = sphere.position:sub(closestPoint)
    local distSq = diff:lengthSq()

    return distSq < (sphere.radius * sphere.radius)
end

function checkAndResolveCubeCubeCollision(cubeA, cubeB)
    local minA = cubeA.position:sub(cubeA.halfExtents)
    local maxA = cubeA.position:add(cubeA.halfExtents)
    local minB = cubeB.position:sub(cubeB.halfExtents)
    local maxB = cubeB.position:add(cubeB.halfExtents)

    local isColliding = (maxA.x > minB.x and minA.x < maxB.x) and
        (maxA.y > minB.y and minA.y < maxB.y) and
        (maxA.z > minB.z and minA.z < maxB.z)

    if not isColliding then
        return
    end

    local overlapX = math.min(maxA.x, maxB.x) - math.max(minA.x, minB.x)
    local overlapY = math.min(maxA.y, maxB.y) - math.max(minA.y, minB.y)
    local overlapZ = math.min(maxA.z, maxB.z) - math.max(minA.z, minB.z)

    local penetration
    local normal

    if overlapX < overlapY and overlapX < overlapZ then
        penetration = overlapX
        if cubeA.position.x < cubeB.position.x then
            normal = Vector3.new(-1, 0, 0)
        else
            normal = Vector3.new(1, 0, 0)
        end
    elseif overlapY < overlapZ then
        penetration = overlapY
        if cubeA.position.y < cubeB.position.y then
            normal = Vector3.new(0, -1, 0)
        else
            normal = Vector3.new(0, 1, 0)
        end
    else
        penetration = overlapZ
        if cubeA.position.z < cubeB.position.z then
            normal = Vector3.new(0, 0, -1)
        else
            normal = Vector3.new(0, 0, 1)
        end
    end

    local totalInvMass = cubeA.invMass + cubeB.invMass
    if totalInvMass == 0 then return end

    local correction = normal:mul(penetration / totalInvMass)
    cubeA.position = cubeA.position:add(correction:mul(cubeA.invMass))
    cubeB.position = cubeB.position:sub(correction:mul(cubeB.invMass))

    local relativeVelocity = cubeA.velocity:sub(cubeB.velocity)
    local velocityAlongNormal = relativeVelocity:dot(normal)

    if velocityAlongNormal < 0 then
        local restitution = math.min(cubeA.bounciness, cubeB.bounciness)
        local impulseScalar = -(1 + restitution) * velocityAlongNormal
        impulseScalar = impulseScalar / totalInvMass

        local impulse = normal:mul(impulseScalar)
        cubeA.velocity = cubeA.velocity:add(impulse:mul(cubeA.invMass))
        cubeB.velocity = cubeB.velocity:sub(impulse:mul(cubeB.invMass))
    end
end

function checkAndResolveBoundaryCollision(obj, bounds)
    local collisionNormal = Vector3.new()
    local penetration = 0

    if obj.type == "sphere" then
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
    elseif obj.type == "cube" then
        local he = obj.halfExtents
        if obj.position.x - he.x < bounds.min.x then
            penetration = bounds.min.x - (obj.position.x - he.x)
            obj.position.x = obj.position.x + penetration
            obj.velocity.x = -obj.velocity.x * obj.bounciness
        elseif obj.position.x + he.x > bounds.max.x then
            penetration = (obj.position.x + he.x) - bounds.max.x
            obj.position.x = obj.position.x - penetration
            obj.velocity.x = -obj.velocity.x * obj.bounciness
        end

        if obj.position.y - he.y < bounds.min.y then
            penetration = bounds.min.y - (obj.position.y - he.y)
            obj.position.y = obj.position.y + penetration
            obj.velocity.y = -obj.velocity.y * obj.bounciness
        elseif obj.position.y + he.y > bounds.max.y then
            penetration = (obj.position.y + he.y) - bounds.max.y
            obj.position.y = obj.position.y - penetration
            obj.velocity.y = -obj.velocity.y * obj.bounciness
        end

        if obj.position.z - he.z < bounds.min.z then
            penetration = bounds.min.z - (obj.position.z - he.z)
            obj.position.z = obj.position.z + penetration
            obj.velocity.z = -obj.velocity.z * obj.bounciness
        elseif obj.position.z + he.z > bounds.max.z then
            penetration = (obj.position.z + he.z) - bounds.max.z
            obj.position.z = obj.position.z - penetration
            obj.velocity.z = -obj.velocity.z * obj.bounciness
        end
    end
end

function drawCube(cube)
    local rotationMatrix = mat4.from_quaternion(cube.orientation)
    local translationMatrix = mat4.from_translation(cube.position)
    local modelMatrix = translationMatrix * rotationMatrix

    local hE = cube.halfExtents
    local localVertices = {
        Vector3.new(-hE.x, -hE.y, -hE.z), -- 0
        Vector3.new(hE.x, -hE.y, -hE.z),  -- 1
        Vector3.new(hE.x, hE.y, -hE.z),   -- 2
        Vector3.new(-hE.x, hE.y, -hE.z),  -- 3
        Vector3.new(-hE.x, -hE.y, hE.z),  -- 4
        Vector3.new(hE.x, -hE.y, hE.z),   -- 5
        Vector3.new(hE.x, hE.y, hE.z),    -- 6
        Vector3.new(-hE.x, hE.y, hE.z)    -- 7
    }

    local worldVertices = {}
    for i, lv in ipairs(localVertices) do
        local transformedVec = mat4.transform_vec3(modelMatrix, lv)
        worldVertices[i] = Vector3.new(transformedVec.x, transformedVec.y, transformedVec.z)
    end

    local faces = {
        { 3, 2, 1, 0 }, -- Front face
        { 4, 5, 6, 7 }, -- Back face
        { 7, 6, 2, 3 }, -- Top face
        { 0, 1, 5, 4 }, -- Bottom face
        { 1, 2, 6, 5 }, -- Right face
        { 4, 7, 3, 0 }  -- Left face
    }

    local projectedVertices = {}
    for i, v in ipairs(worldVertices) do
        local sx, sy, depth = cam:project(v)
        projectedVertices[i] = { x = sx, y = sy, depth = depth, valid = sx and true or false }
    end

    local facesToDraw = {}
    for _, faceIndices in ipairs(faces) do
        local v1 = worldVertices[faceIndices[1] + 1]
        local v2 = worldVertices[faceIndices[2] + 1]
        local v3 = worldVertices[faceIndices[3] + 1]

        local edge1 = v2:sub(v1)
        local edge2 = v3:sub(v1)
        local faceNormal = edge1:cross(edge2):normalize()
        local viewVector = (v1:sub(cam.position)):normalize()

        if faceNormal:dot(viewVector) < 0 then
            local pointsForPolygon = {}
            local averageDepth = 0
            local allVerticesValid = true

            for _, vertIndex in ipairs(faceIndices) do
                local pv = projectedVertices[vertIndex + 1]
                if pv.valid then
                    table.insert(pointsForPolygon, pv.x)
                    table.insert(pointsForPolygon, pv.y)
                    averageDepth = averageDepth + pv.depth
                else
                    allVerticesValid = false
                    break
                end
            end

            if allVerticesValid then
                table.insert(facesToDraw, {
                    points = pointsForPolygon,
                    depth = averageDepth / #faceIndices,
                    color = cube.color
                })
            end
        end
    end

    table.sort(facesToDraw, function(a, b)
        return a.depth > b.depth
    end)

    for _, faceData in ipairs(facesToDraw) do
        local v1 = worldVertices[faces[1][1] + 1]
        local faceNormal = (worldVertices[2]:sub(worldVertices[1])):cross(worldVertices[4]:sub(worldVertices[1]))
            :normalize()
        local lightDir = Vector3.new(0.5, -1, 0.5):normalize()
        local brightness = math.max(0.2, faceNormal:dot(lightDir:mul(-1)))

        local shadedColor = {
            faceData.color[1] * brightness,
            faceData.color[2] * brightness,
            faceData.color[3] * brightness,
            faceData.color[4]
        }

        love.graphics.setColor(shadedColor)
        love.graphics.polygon("fill", faceData.points)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("line", faceData.points)
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
        if obj.type == "sphere" then
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
        elseif obj.type == "cube" then
            drawCube(obj)
        end
    end

    love.graphics.setColor(1, 1, 1, 0.5)
    local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    love.graphics.line(cx - 10, cy, cx + 10, cy)
    love.graphics.line(cx, cy - 10, cx, cy + 10)
end