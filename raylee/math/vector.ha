use math;

export type vector3 = struct { x: f64, y: f64, z: f64 };
export type point = vector3;

export fn v3(x: f64, y: f64, z: f64) vector3 = vector3 { x = x, y = y, z = z };
export fn vsplat(value: f64) vector3 = vector3 { x = value, y = value, z = value };

export fn vadd(lhs: vector3, rhs: vector3) vector3 = vector3 {
    x = lhs.x + rhs.x,
    y = lhs.y + rhs.y,
    z = lhs.z + rhs.z,
};

export fn vsub(lhs: vector3, rhs: vector3) vector3 = vector3 {
    x = lhs.x - rhs.x,
    y = lhs.y - rhs.y,
    z = lhs.z - rhs.z,
};

export fn vmul(lhs: vector3, rhs: vector3) vector3 = vector3 {
    x = lhs.x * rhs.x,
    y = lhs.y * rhs.y,
    z = lhs.z * rhs.z,
};

export fn vdiv(lhs: vector3, rhs: vector3) vector3 = vector3 {
    x = lhs.x / rhs.x,
    y = lhs.y / rhs.y,
    z = lhs.z / rhs.z,
};

export fn vdot(lhs: vector3, rhs: vector3) f64 =
    lhs.x * rhs.x +
    lhs.y * rhs.y +
    lhs.z * rhs.z
;

export fn vunit(self: vector3) vector3 = vdiv(self, vsplat(length(self)));
export fn length(self: vector3) f64 = math::sqrtf64(length_squared(self));

export fn length_squared(self: vector3) f64 =
    self.x * self.x +
    self.y * self.y +
    self.z * self.z
;
