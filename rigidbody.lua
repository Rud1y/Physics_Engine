local Vector3 = require("vector3")

local RigidBody = {}
RigidBody.__index = RigidBody

function RigidBody.new(params)
    local self = setmetatable({}, RigidBody)
    self.position = params.position or Vector3.new(0, 0, 0)
    self.velocity = Vector3.new(0, 0, 0)
    self.acceleration = Vector3.new(0, 0, 0)
    self.orientation = { x = 0, y = 0, z = 0, w = 1 }
    self.angularVelocity = Vector3.new(0, 0, 0)

    self.mass = params.mass or 1
    if self.mass > 0 then
        self.invMass = 1 / self.mass
    else
        self.invMass = 0
    end

    self.bounciness = params.bounciness or 1
    self.color = params.color or { math.random(), math.random(), math.random(), 1 }

    self.type = params.type or "undefined"
    if self.type == "sphere" then
        self.radius = params.radius or 1
    elseif self.type == "cube" then
        self.halfExtents = params.halfExtents or Vector3.new(1, 1, 1)
    end

    return self
end

function RigidBody:applyForce(force)
    self.acceleration = self.acceleration:add(force:mul(self.invMass))
end

function RigidBody:update(dt)
    self.velocity = self.velocity:add(self.acceleration:mul(dt))
    self.position = self.position:add(self.velocity:mul(dt))
    if self.type == "cube" then
        local p = self.position
        local hE = self.halfExtents
        self.vertices = {
            p:add(Vector3.new(-hE.x, -hE.y, -hE.z)), -- 0: Front, bottom, left
            p:add(Vector3.new(hE.x, -hE.y, -hE.z)),  -- 1: Front, bottom, right
            p:add(Vector3.new(hE.x, hE.y, -hE.z)),   -- 2: Front, top, right
            p:add(Vector3.new(-hE.x, hE.y, -hE.z)),  -- 3: Front, top, left
            p:add(Vector3.new(-hE.x, -hE.y, hE.z)),  -- 4: Back, bottom, left
            p:add(Vector3.new(hE.x, -hE.y, hE.z)),   -- 5: Back, bottom, right
            p:add(Vector3.new(hE.x, hE.y, hE.z)),    -- 6: Back, top, right
            p:add(Vector3.new(-hE.x, hE.y, hE.z))    -- 7: Back, top, left
        }
    end

    local q_vel = {
        x = self.angularVelocity.x * 0.1 * dt,
        y = self.angularVelocity.y * 0.1 * dt,
        z = self.angularVelocity.z * 0.1 * dt,
        w = 0
    }

    local q_old = self.orientation
    local q_new_x = q_vel.w * q_old.x + q_vel.x * q_old.w + q_vel.y * q_old.z - q_vel.z * q_old.y
    local q_new_y = q_vel.w * q_old.y - q_vel.x * q_old.z + q_vel.y * q_old.w + q_vel.z * q_old.x
    local q_new_z = q_vel.w * q_old.z + q_vel.x * q_old.y - q_vel.y * q_old.x + q_vel.z * q_old.w
    local q_new_w = q_vel.w * q_old.w - q_vel.x * q_old.x - q_vel.y * q_old.y - q_vel.z * q_old.z

    self.orientation.x = self.orientation.x + q_new_x
    self.orientation.y = self.orientation.y + q_new_y
    self.orientation.z = self.orientation.z + q_new_z
    self.orientation.w = self.orientation.w + q_new_w

    local mag = math.sqrt(self.orientation.x ^ 2 + self.orientation.y ^ 2 + self.orientation.z ^ 2 + self.orientation.w ^ 2)
    if mag > 0 then
        self.orientation.x = self.orientation.x / mag
        self.orientation.y = self.orientation.y / mag
        self.orientation.z = self.orientation.z / mag
        self.orientation.w = self.orientation.w / mag
    end

    self.acceleration = Vector3.new(0, 0, 0)
end

return RigidBody