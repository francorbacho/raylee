use raylee::math;
use raylee::math::{
    ray, point,
    vsplat, v3,
    vsub, vdot, vunit,
    rtravel,
};

use fmt;

use math;

export type surface_vtable = struct {
    hit: *fn(**surface_vtable, ray) (void | raylee::math::color),
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

fn hit_sphere(surface: **surface_vtable, ray: ray) (void | raylee::math::color) = {
    const sphere = surface: *surface_sphere;

    const oc = vsub(ray.origin, sphere.center);
    const a = vdot(ray.direction, ray.direction);
    const b = 2.0 * vdot(oc, ray.direction);
    const c = vdot(oc, oc) - sphere.radius * sphere.radius;
    const discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0)
        return;

    const distance = (-b - math::sqrtf64(discriminant)) / (2.0 * a);
    const light_direction = vunit(v3(0.8, 0.3, 0.7));

    let normal = rtravel(ray, distance);
    normal = vsub(normal, sphere.center);
    normal = vunit(normal);
    const lcf = (1.0 + vdot(normal, light_direction)) / 2.0;

    return vsplat(lcf);
};
