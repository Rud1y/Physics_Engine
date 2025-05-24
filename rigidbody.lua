local Vector3 = require("vector3")

local RigidBody = {}
RigidBody.__index = RigidBody

function RigidBody.new(x, y, z, radius, mass)
    local self = setmetatable({}, RigidBody)
    self.position = Vector3.new(x, y, z)
    self.velocity = Vector3.new(0, 0, 0)
    self.acceleration = Vector3.new(0, 0, 0) -- For accumulated forces
    self.radius = radius or 1
    self.mass = mass or 1
    if self.mass <= 0 then self.mass = 1 end -- Avoid division by zero for inverse mass
    self.invMass = 1 / self.mass
    self.restitution = 0.7                   -- Bounciness (0 to 1)
    self.color = { math.random(), math.random(), math.random(), 1 }
    return self
end

function RigidBody:applyForce(force)
    self.acceleration = self.acceleration:add(force:mul(self.invMass))
end

function RigidBody:update(dt)
    -- Basic Euler integration
    self.velocity = self.velocity:add(self.acceleration:mul(dt))
    self.position = self.position:add(self.velocity:mul(dt))
    self.acceleration = Vector3.new(0, 0, 0) -- Clear forces for next frame
end

return RigidBody