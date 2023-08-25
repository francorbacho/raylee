use raylee::math;
use raylee::math::{
    vector3, ray, point, v3,
    vsub, vdot, vunit,
    rtravel,
};

use fmt;

use math;

export type hit_record = struct {
    where: point,
    normal: vector3,
    distance: f64,
    front_face: bool,
};

export type surface_vtable = struct {
    hit: *fn(**surface_vtable, ray, f64, f64) (void | hit_record),
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

fn hit_sphere(
    surface: **surface_vtable,
    ray: ray,
    min_dist: f64,
    max_dist: f64
) (void | hit_record) = {
    const sphere = surface: *surface_sphere;

    const oc = vsub(ray.origin, sphere.center);
    const a = vdot(ray.direction, ray.direction);
    const b = 2.0 * vdot(oc, ray.direction);
    const c = vdot(oc, oc) - sphere.radius * sphere.radius;
    const discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0)
        return;

    const disc_sqrt = math::sqrtf64(discriminant);

    let distance = (-b - disc_sqrt) / (2.0 * a);
    if (distance < min_dist || distance > max_dist) {
        distance = (-b + disc_sqrt) / (2.0 * a);
        if (distance < min_dist || distance > max_dist)
            return;
    };

    const where = rtravel(ray, distance);
    const normal = vunit(vsub(where, sphere.center));
    const front_face = vdot(ray.direction, normal) < 0.0;

    return hit_record {
        where = where,
        distance = distance,
        normal = normal,
        front_face = front_face,
    };
};

export type surface_compose = struct {
    vtable: *surface_vtable,
    surfaces: []**surface_vtable,
};

export const compose_vtable: surface_vtable = surface_vtable {
    hit = &hit_compose,
};

export fn compose(surfaces: **surface_vtable...) surface_compose = {
    const surfaces: []**surface_vtable = surfaces;

    return surface_compose {
        vtable = &compose_vtable,
        surfaces = surfaces
    };
};

fn hit_compose(
    surface: **surface_vtable,
    ray: ray,
    min_dist: f64,
    max_dist: f64,
) (void | hit_record) = {
    const compose = surface: *surface_compose;
    let closest_hit = max_dist;
    let record: (void | hit_record) = void;

    for (let i = 0z; i < len(compose.surfaces); i += 1) {
        const surface = compose.surfaces[i];
        match (surface.hit(surface, ray, min_dist, closest_hit)) {
        case void =>
            void;
        case let new_hit: hit_record =>
            if (!new_hit.front_face) {
                fmt::errorln("warn: Camera clipping")!;
                continue;
            };

            if (min_dist < new_hit.distance && new_hit.distance < closest_hit) {
                closest_hit = new_hit.distance;
                record = new_hit;
            };
        };
    };

    return record;
};

export fn hit_surface_compose(surface: surface_compose, ray: ray) (void | hit_record) = {
    return hit_compose(&surface, ray, 0.0, math::INF);
};
