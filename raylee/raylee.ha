use raylee::math;
use raylee::math::{
    color, vector3, point, ray,
    rgb, v3, vsplat,
    randvec,
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
        tmp = vdiv(tmp, 2.0);
        tmp = vadd(tmp, viewport_topleft);
        yield tmp;
    };

    scene.surfaces = compose(
        &sphere(v3(-1.0,    0.0, -2.0), 0.5),
        &sphere(v3( 1.0,    0.0, -2.0), 0.5),
        &sphere(v3( 0.0, -100.5, -1.0), 100.0),
    );

    let pixels: []color = [];

    for (let j = 0z; j < scene.height; j += 1) {
        for (let i = 0z; i < scene.width; i += 1) {
            const pixel_ji = {
                let tmp = viewport_coordinate_frame;
                tmp = vmul(tmp, v3(i: f64, j: f64, 0.0));
                tmp = vadd(tmp, pixel_00);
                yield tmp;
            };

            let color_ji = vsplat(0.0);
            for (let k = 0z; k < scene.samples_per_pixel; k += 1) {
                const random_pixel_offset = vmul(randvec(&scene.rng), viewport_coordinate_frame);
                const pixel_jik = vadd(pixel_ji, random_pixel_offset);

                let ray_jik = ray {
                    origin = scene.camera.position,
                    direction = vunit(vsub(pixel_jik, scene.camera.position)),
                };

                const color_jik = ray_color(&scene, scene.surfaces, ray_jik);
                color_ji = vadd(color_ji, color_jik);
            };

            color_ji = vmul(color_ji, 1.0 / scene.samples_per_pixel: f64);
            color_ji = vmul(color_ji, 255.0);
            append(pixels, color_ji);
        };
    };

    return image {
        width = scene.width,
        height = scene.height,
        pixels = pixels,
    };
};

fn ray_color(scene: *scene, surface: surface_compose, ray: ray) color = {
    match (hit_surface_compose(surface, ray)) {
    case void => yield;
    case let hit: hit_record =>
        const lcf = (1.0 + vdot(hit.normal, scene.light_direction)) / 2.0;
        return vsplat(lcf);
    };

    const direction_unit = ray.direction;

    const blue = rgb(0.5, 0.7, 1.0);
    const white = rgb(1.0, 1.0, 1.0);

    const f = (direction_unit.y + 1.0) * 0.5;
    return raylee::math::lerp(f, white, blue);
};
