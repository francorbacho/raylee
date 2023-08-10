use math;

export type vector3 = struct { x: f64, y: f64, z: f64 };
export type point = vector3;

export fn splat(value: f64) vector3 = vector3 { x = value, y = value, z = value };

export fn add(lhs: *vector3, rhs: *const vector3) void = {
    lhs.x += rhs.x;
    lhs.y += rhs.y;
    lhs.z += rhs.z;
};

export fn sub(lhs: *vector3, rhs: *const vector3) void = {
    lhs.x -= rhs.x;
    lhs.y -= rhs.y;
    lhs.z -= rhs.z;
};

export fn mul(lhs: *vector3, rhs: *const vector3) void = {
    lhs.x *= rhs.x;
    lhs.y *= rhs.y;
    lhs.z *= rhs.z;
};

export fn div(lhs: *vector3, rhs: *const vector3) void = {
    lhs.x /= rhs.x;
    lhs.y /= rhs.y;
    lhs.z /= rhs.z;
};

export fn dot(lhs: *vector3, rhs: *const vector3) f64 = {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
};

export fn unit(self: *vector3) void = {
    div(self, &splat(length(self)));
};

export fn length(self: *vector3) f64 = {
    return math::sqrtf64(length_squared(self));
};

export fn length_squared(self: *vector3) f64 = {
    return self.x * self.x + self.y * self.y + self.z * self.z;
};
