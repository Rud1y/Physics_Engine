local love = require("love")


local Vector3 = require("vector3")

local Camera = {}
Camera.__index = Camera

function Camera.new(pos, lookAt, up, fov, aspect, near, far)
    local self = setmetatable({}, Camera)
    self.position = pos or Vector3.new(0, 5, -10)
    self.lookAtPoint = lookAt or Vector3.new(0, 0, 0)
    self.worldUp = up or Vector3.new(0, 1, 0)

    self.fov = fov or math.rad(60) -- Field of view in radians
    self.aspect = aspect or love.graphics.getWidth() / love.graphics.getHeight()
    self.near = near or 0.1
    self.far = far or 200

    -- Camera basis vectors
    self.forward = (self.lookAtPoint:sub(self.position)):normalize()
    self.right = (self.forward:cross(self.worldUp)):normalize()
    self.up = (self.right:cross(self.forward)):normalize() -- Recalculate up to be orthogonal

    return self
end

-- Projects a 3D world point to 2D screen coordinates
function Camera:project(worldPos)
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()

    -- 1. World to Camera Space
    local camRelativePos = worldPos:sub(self.position)
    local camX = camRelativePos:dot(self.right)
    local camY = camRelativePos:dot(self.up)
    local camZ = camRelativePos:dot(self.forward) -- This is depth

    if camZ < self.near or camZ > self.far then   -- Basic culling
        return nil, nil, -math.huge               -- Return nil if behind camera or too far
    end

    -- 2. Perspective Projection (Simplified - projects onto near plane)
    -- Similar triangles: screenX / camX = f / camZ  => screenX = camX * f / camZ
    -- 'f' is related to FOV. For FOV_y, f_y = 1 / tan(fov_y / 2)
    local f_y = 1 / math.tan(self.fov / 2)
    local f_x = f_y / self.aspect -- Adjust for aspect ratio

    -- Projected coordinates on near plane (normalized device coordinates-like)
    local ndcX = (camX * f_x) / camZ
    local ndcY = (camY * f_y) / camZ
    -- ndcX and ndcY are usually in range [-1, 1] for points within frustum

    -- 3. Viewport Transform (NDC to Screen Coordinates)
    local screenX = (ndcX + 1) * 0.5 * width
    local screenY = (1 - ndcY) * 0.5 * height -- Y is typically inverted

    -- Return depth as well, for sorting or scaling
    return screenX, screenY, camZ
end

-- Allows simple mouse look (call from love.mousemoved)
function Camera:mouseLook(dx, dy, sensitivity)
    sensitivity = sensitivity or 0.002

    -- Horizontal rotation (around world up)
    local yawAngle = dx * sensitivity
    -- Rotate forward and right vectors around worldUp
    local cosYaw = math.cos(yawAngle)
    local sinYaw = math.sin(yawAngle)

    local newForwardX = self.forward.x * cosYaw - self.forward.z * sinYaw
    local newForwardZ = self.forward.x * sinYaw + self.forward.z * cosYaw
    self.forward.x, self.forward.z = newForwardX, newForwardZ
    self.forward = self.forward:normalize()

    local newRightX = self.right.x * cosYaw - self.right.z * sinYaw
    local newRightZ = self.right.x * sinYaw + self.right.z * cosYaw
    self.right.x, self.right.z = newRightX, newRightZ
    self.right = self.right:normalize()

    -- Vertical rotation (around camera's right vector)
    local pitchAngle = -dy * sensitivity
    local cosPitch = math.cos(pitchAngle)
    local sinPitch = math.sin(pitchAngle)

    -- Rotate forward and up vectors around right
    local newForward = self.forward:mul(cosPitch):add(self.up:mul(sinPitch))
    local newUp = self.up:mul(cosPitch):sub(self.forward:mul(sinPitch))

    -- Prevent gimbal lock/flipping by limiting pitch
    if newUp:dot(self.worldUp) > 0.1 then -- Check if not too close to vertical
        self.forward = newForward:normalize()
        self.up = newUp:normalize()
    end

    -- Update lookAtPoint (not strictly needed if just using vectors, but good for consistency)
    self.lookAtPoint = self.position:add(self.forward)
    -- Ensure right vector is still orthogonal to new forward and up
    self.right = (self.forward:cross(self.worldUp)):normalize()
    self.up = (self.right:cross(self.forward)):normalize()
end

return Camera