local love = require("love")


local Vector3 = require("vector3")

local Camera = {}
Camera.__index = Camera

function Camera.new(pos, lookAt, up, fov, aspect, near, far)
    local self = setmetatable({}, Camera)
    self.position = pos or Vector3.new(0, 5, -10)
    self.lookAtPoint = lookAt or Vector3.new(0, 0, 0)
    self.worldUp = up or Vector3.new(0, 1, 0)

    self.fov = fov or math.rad(60)
    self.aspect = aspect or love.graphics.getWidth() / love.graphics.getHeight()
    self.near = near or 0.1
    self.far = far or 200

    self.forward = (self.lookAtPoint:sub(self.position)):normalize()
    self.right = (self.forward:cross(self.worldUp)):normalize()
    self.up = (self.right:cross(self.forward)):normalize()

    return self
end

function Camera:project(worldPos)
    local width, height = love.graphics.getWidth(), love.graphics.getHeight()

    local camRelativePos = worldPos:sub(self.position)
    local camX = camRelativePos:dot(self.right)
    local camY = camRelativePos:dot(self.up)
    local camZ = camRelativePos:dot(self.forward)

    if camZ < self.near or camZ > self.far then
        return nil, nil, -math.huge
    end

    local f_y = 1 / math.tan(self.fov / 2)
    local f_x = f_y / self.aspect

    local ndcX = (camX * f_x) / camZ
    local ndcY = (camY * f_y) / camZ

    local screenX = (ndcX + 1) * 0.5 * width
    local screenY = (1 - ndcY) * 0.5 * height

    return screenX, screenY, camZ
end

function Camera:mouseLook(dx, dy, sensitivity)
    sensitivity = sensitivity or 0.002

    local yawAngle = dx * sensitivity
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

    local pitchAngle = -dy * sensitivity
    local cosPitch = math.cos(pitchAngle)
    local sinPitch = math.sin(pitchAngle)

    local newForward = self.forward:mul(cosPitch):add(self.up:mul(sinPitch))
    local newUp = self.up:mul(cosPitch):sub(self.forward:mul(sinPitch))

    if newUp:dot(self.worldUp) > 0.1 then
        self.forward = newForward:normalize()
        self.up = newUp:normalize()
    end

    self.lookAtPoint = self.position:add(self.forward)
    self.right = (self.forward:cross(self.worldUp)):normalize()
    self.up = (self.right:cross(self.forward)):normalize()
end

return Camera