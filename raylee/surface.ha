use raylee::math;
use raylee::math::{
    vector3, ray, point,
    vsplat, v3,
    vsub, vdot, vunit,
    rtravel,
};

use fmt;

use math;

export type hit_record = struct {
    where: point,
    normal: vector3,
    distance: f64,
};

export type surface_vtable = struct {
    hit: *fn(**surface_vtable, ray) (void | hit_record),
};

export type surface_sphere = struct {
    vtable: *surface_vtable,
    center: point,
    radius: f64,
};

export const sphere_vtable: surface_vtable = surface_vtable {
    hit = &hit_sphere,
};

export fn sphere(center: point, radius: f64) surface_sphere = {
    return surface_sphere {
        vtable = &sphere_vtable,
        center = center,
        radius = radius,
    };
};

fn hit_sphere(surface: **surface_vtable, ray: ray) (void | hit_record) = {
    const sphere = surface: *surface_sphere;

    const oc = vsub(ray.origin, sphere.center);
    const a = vdot(ray.direction, ray.direction);
    const b = 2.0 * vdot(oc, ray.direction);
    const c = vdot(oc, oc) - sphere.radius * sphere.radius;
    const discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0)
        return;

    let distance = (-b - math::sqrtf64(discriminant)) / (2.0 * a);

    if (distance < 0.0) {
        distance = (-b + math::sqrtf64(discriminant)) / (2.0 * a);
    };

    const where = rtravel(ray, distance);
    const normal = vunit(vsub(where, sphere.center));

    return hit_record {
        where = where,
        distance = distance,
        normal = normal,
    };
};
