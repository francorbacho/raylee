use math;
use math::random;

export type vector3 = struct { x: f64, y: f64, z: f64 };
export type point = vector3;
export type vector2 = vector3;

export fn v3(x: f64, y: f64, z: f64) vector3 = vector3 { x = x, y = y, z = z };
export fn vsplat(value: f64) vector3 = vector3 { x = value, y = value, z = value };

export type implicitv3 = (vector3 | f64);

export fn intov3(value: implicitv3) vector3 = match (value) {
case let vec: vector3 => return vec;
case let val: f64 => return vsplat(val);
};

export fn randvec(random: *random::random) vector3 = v3(
    random::f64rand(random),
    random::f64rand(random),
    random::f64rand(random),
);

export fn vadd(lhs: vector3, rhs: implicitv3) vector3 = {
    const rhs = intov3(rhs);
    return vector3 {
        x = lhs.x + rhs.x,
        y = lhs.y + rhs.y,
        z = lhs.z + rhs.z,
    };
};

export fn vsub(lhs: vector3, rhs: implicitv3) vector3 = {
    const rhs = intov3(rhs);
    return vector3 {
        x = lhs.x - rhs.x,
        y = lhs.y - rhs.y,
        z = lhs.z - rhs.z,
    };
};

export fn vmul(lhs: vector3, rhs: implicitv3) vector3 = {
    const rhs = intov3(rhs);
    return vector3 {
        x = lhs.x * rhs.x,
        y = lhs.y * rhs.y,
        z = lhs.z * rhs.z,
    };
};

export fn vdiv(lhs: vector3, rhs: implicitv3) vector3 = {
    const rhs = intov3(rhs);
    return vector3 {
        x = lhs.x / rhs.x,
        y = lhs.y / rhs.y,
        z = lhs.z / rhs.z,
    };
};

export fn vdot(lhs: vector3, rhs: implicitv3) f64 = {
    const rhs = intov3(rhs);
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
};

export fn vunit(self: vector3) vector3 = vdiv(self, length(self));
export fn length(self: vector3) f64 = math::sqrtf64(length_squared(self));

export fn length_squared(self: vector3) f64 =
    self.x * self.x +
    self.y * self.y +
    self.z * self.z
;
