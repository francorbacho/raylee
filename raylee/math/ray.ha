export type ray = struct {
    origin: point,
    direction: vector3,
};

export fn rtravel(ray: ray, v: f64) point = vadd(
    ray.origin, vmul(ray.direction, v)
);
