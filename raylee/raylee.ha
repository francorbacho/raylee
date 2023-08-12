use raylee::math;
use raylee::math::{
    color, vector3, point, ray,
    rgb, v3, vsplat,
    vadd, vsub, vmul, vdiv, vdot, vunit,
    rtravel
};

use math;

use fmt;

export type image = struct {
    width: uint,
    height: uint,
    pixels: []color,
};

export fn scene(width: u32, height: u32) image = {
    const camera_position = point { ... };

    const focal_length: f64 = 1.0;
    const aspect_ratio: f64 = width: f32 / height: f32;

    const viewport_dim = {
        const viewport_height: f64 = 2.0;
        const viewport_width: f64 = viewport_height * aspect_ratio;
        yield v3(viewport_width, viewport_height, 1.0);
    };

    const viewport_coordinate_frame = {
        let tmp = vdiv(viewport_dim, v3(width: f64, height: f64, 1.0));
        // Change the direction of the coordinate frame to have the topleft pixel
        // be the j0i0.
        tmp.y = -tmp.y;
        yield tmp;
    };

    const viewport_topleft = {
        let tmp = camera_position;
        tmp = vadd(tmp, v3(0.0, 0.0, -focal_length));
        tmp = vadd(tmp, v3(-viewport_dim.x / 2.0, viewport_dim.y / 2.0, 0.0));
        yield tmp;
    };

    const pixel_00 = {
        let tmp1 = viewport_topleft;
        let tmp2 = viewport_coordinate_frame;

        tmp2 = vdiv(tmp2, vsplat(2.0));
        tmp1 = vadd(tmp1, tmp2);

        yield tmp1;
    };

    let pixels: []color = [];

    for (let j = 0z; j < height; j += 1) {
        for (let i = 0z; i < width; i += 1) {
            const pixel_ji = {
                let tmp = viewport_coordinate_frame;
                tmp = vmul(tmp, v3(i: f64, j: f64, 0.0));
                tmp = vadd(tmp, pixel_00);
                yield tmp;
            };

            const ray_ji = ray {
                origin = pixel_ji,
                direction = vunit(vsub(pixel_ji, camera_position)),
            };

            let color_ji = ray_color(ray_ji);
            color_ji = vmul(color_ji, vsplat(255.0));
            append(pixels, color_ji);
        };
    };

    return image {
        width = width,
        height = height,
        pixels = pixels,
    };
};


fn hit_sphere(center: point, radius: f64, ray: ray) f64 = {
    const oc = vsub(ray.origin, center);
    const a = vdot(ray.direction, ray.direction);
    const b = 2.0 * vdot(oc, ray.direction);
    const c = vdot(oc, oc) - radius * radius;
    const discriminant = b * b - 4.0 * a * c;

    if (discriminant < 0.0) {
        return -1.0;
    } else {
        return (-b - math::sqrtf64(discriminant)) / (2.0 * a);
    };
};

fn ray_color(ray: ray) color = {
    const sphere_center = v3(0.0, 0.0, -1.0);
    const distance = hit_sphere(sphere_center, 0.5, ray);
    if (distance > 0.0) {
        let color = rtravel(ray, distance);
        color = vsub(color, sphere_center);
        color = vunit(color);
        color = vadd(color, vsplat(1.0));
        color = vmul(color, vsplat(0.5));
        return color;
    };

    const direction_unit = ray.direction;

    const blue = rgb(0.5, 0.7, 1.0);
    const white = rgb(1.0, 1.0, 1.0);

    const f = (direction_unit.y + 1.0) * 0.5;
    return raylee::math::lerp(f, white, blue);
};
