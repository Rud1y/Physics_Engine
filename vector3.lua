local Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x, y, z)
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vector3)
end

function Vector3:clone()
    return Vector3.new(self.x, self.y, self.z)
end

function Vector3:add(other)
    return Vector3.new(self.x + other.x, self.y + other.y, self.z + other.z)
end

function Vector3:sub(other)
    return Vector3.new(self.x - other.x, self.y - other.y, self.z - other.z)
end

function Vector3:mul(scalar)
    return Vector3.new(self.x * scalar, self.y * scalar, self.z * scalar)
end

function Vector3:div(scalar)
    if scalar == 0 then error("Division by zero") end
    return Vector3.new(self.x / scalar, self.y / scalar, self.z / scalar)
end

function Vector3:dot(other)
    return self.x * other.x + self.y * other.y + self.z * other.z
end

function Vector3:lengthSq()
    return self.x * self.x + self.y * self.y + self.z * self.z
end

function Vector3:length()
    return math.sqrt(self:lengthSq())
end

function Vector3:normalize()
    local len = self:length()
    if len > 0 then
        return self:div(len)
    end
    return Vector3.new(0, 0, 0) -- Or handle error/return specific vector
end

-- Basic cross product
function Vector3:cross(other)
    return Vector3.new(
        self.y * other.z - self.z * other.y,
        self.z * other.x - self.x * other.z,
        self.x * other.y - self.y * other.x
    )
end

return Vector3