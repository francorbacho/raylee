use raylee::math;
use raylee::math::{
    color, vector3, point, ray,
    rgb, v3, vsplat,
    vadd, vsub, vmul, vdiv, vdot, vunit,
    rtravel
};

use math;

use fmt;

export fn render(scene: scene) image = {
    const viewport_size = scene.camera.viewport_size;
    const viewport_coordinate_frame = {
        let tmp = vdiv(viewport_size, v3(scene.width: f64, scene.height: f64, 1.0));
        // Change the direction of the coordinate frame to have the topleft pixel
        // be the j0i0.
        tmp.y = -tmp.y;
        yield tmp;
    };

    const viewport_topleft = {
        let tmp = scene.camera.position;
        tmp = vadd(tmp, v3(0.0, 0.0, -scene.camera.focal_length));
        tmp = vadd(tmp, v3(-viewport_size.x / 2.0, viewport_size.y / 2.0, 0.0));
        yield tmp;
    };

    const pixel_00 = {
        let tmp = viewport_coordinate_frame;
        tmp = vdiv(tmp, vsplat(2.0));
        tmp = vadd(tmp, viewport_topleft);
        yield tmp;
    };

    let surfaces: []**surface_vtable = [&sphere(v3(0.0, 0.0, -1.0), 0.5)];
    let pixels: []color = [];

    for (let j = 0z; j < scene.height; j += 1) {
        for (let i = 0z; i < scene.width; i += 1) {
            const pixel_ji = {
                let tmp = viewport_coordinate_frame;
                tmp = vmul(tmp, v3(i: f64, j: f64, 0.0));
                tmp = vadd(tmp, pixel_00);
                yield tmp;
            };

            const ray_ji = ray {
                origin = pixel_ji,
                direction = vunit(vsub(pixel_ji, scene.camera.position)),
            };

            let color_ji = ray_color(surfaces, ray_ji);
            color_ji = vmul(color_ji, vsplat(255.0));
            append(pixels, color_ji);
        };
    };

    return image {
        width = scene.width,
        height = scene.height,
        pixels = pixels,
    };
};

fn ray_color(surfaces: []**surface_vtable, ray: ray) color = {
    for (let i = 0z; i < len(surfaces); i += 1) {
        let surface = surfaces[i];

        match (surface.hit(surface, ray)) {
        case void => yield;
        case let color: color =>
            return color;
        };
    };

    const direction_unit = ray.direction;

    const blue = rgb(0.5, 0.7, 1.0);
    const white = rgb(1.0, 1.0, 1.0);

    const f = (direction_unit.y + 1.0) * 0.5;
    return raylee::math::lerp(f, white, blue);
};
